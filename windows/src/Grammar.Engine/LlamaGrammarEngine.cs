using System.Text;
using Grammar.Core.Engine;
using LLama;
using LLama.Common;
using LLama.Native;

namespace Grammar.Engine;

/// <summary>Phần cứng đang chạy model.</summary>
public enum ComputeBackend
{
    Gpu,
    Cpu,
}

/// <summary>
/// Sửa ngữ pháp bằng llama.cpp chạy trên máy (qua LLamaSharp). Port của GrammarKit/Engine/LlamaGrammarEngine.swift.
/// </summary>
/// <remarks>
/// Mọi lời gọi native đi qua một <see cref="SemaphoreSlim"/>(1), tương đương <c>actor</c> của bản Swift:
/// không bao giờ có hai lời gọi chạy song song.
/// </remarks>
public sealed class LlamaGrammarEngine : IGrammarEngine, IDisposable
{
    public sealed record Configuration
    {
        public uint ContextSize { get; init; } = 2048;
        /// <summary>Số layer đưa lên GPU. Số lớn = toàn bộ; 0 = chỉ chạy CPU.</summary>
        public int GpuLayers { get; init; } = 999;
    }

    private static readonly LLamaSeqId Sequence = (LLamaSeqId)0;

    private readonly LLamaWeights _weights;
    private readonly LLamaContext _context;
    private readonly SafeLLamaSamplerChainHandle _sampler;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private readonly int _batchSize;

    /// <summary>Token của prompt cố định đang nằm trong KV cache (rỗng = chưa có).</summary>
    private LLamaToken[] _cachedPrefix = [];
    private LLamaToken[]? _fixedPrefix;
    private bool _disposed;

    public string ModelPath { get; }

    /// <summary>Số layer thực sự nằm trên GPU (đọc từ log của llama.cpp khi nạp model).</summary>
    public int OffloadedLayers { get; }

    public ComputeBackend Backend => OffloadedLayers > 0 ? ComputeBackend.Gpu : ComputeBackend.Cpu;

    private SafeLLamaContextHandle Native => _context.NativeHandle;

    /// <exception cref="GrammarEngineException">Không nạp được model hoặc không tạo được ngữ cảnh.</exception>
    public LlamaGrammarEngine(string modelPath, Configuration? configuration = null)
    {
        configuration ??= new Configuration();
        ModelPath = modelPath;
        if (!File.Exists(modelPath)) throw new GrammarEngineException(GrammarEngineErrorKind.ModelLoadFailed, modelPath);

        NativeBackend.EnsureConfigured();
        var parameters = new ModelParams(modelPath)
        {
            ContextSize = configuration.ContextSize,
            BatchSize = configuration.ContextSize,
            GpuLayerCount = configuration.GpuLayers,
        };
        _batchSize = (int)configuration.ContextSize;

        string log;
        try
        {
            (_weights, log) = NativeBackend.Capture(() => LLamaWeights.LoadFromFile(parameters));
        }
        catch (Exception e)
        {
            throw new GrammarEngineException(GrammarEngineErrorKind.ModelLoadFailed, modelPath, e);
        }
        OffloadedLayers = configuration.GpuLayers == 0 ? 0 : NativeBackend.OffloadedLayers(log) ?? 0;

        try
        {
            _context = _weights.CreateContext(parameters);
        }
        catch (Exception e)
        {
            _weights.Dispose();
            throw new GrammarEngineException(GrammarEngineErrorKind.ContextCreationFailed, null, e);
        }

        // temperature = 0: luôn chọn token có xác suất cao nhất.
        _sampler = SafeLLamaSamplerChainHandle.Create(LLamaSamplerChainParams.Default());
        _sampler.AddGreedySampler();
    }

    /// <summary>Chạy một câu để nạp shader/bộ nhớ, giúp lần kiểm tra đầu tiên nhanh hơn. Lỗi thì ném ra.</summary>
    public Task WarmUpAsync(CancellationToken cancellationToken = default) =>
        CorrectAsync("This are a warm up sentence.", cancellationToken);

    public async Task<string> CorrectAsync(string sentence, CancellationToken cancellationToken = default)
    {
        await _lock.WaitAsync(cancellationToken);
        try
        {
            ObjectDisposedException.ThrowIf(_disposed, this);
            return await Task.Run(() => Correct(sentence, cancellationToken), cancellationToken);
        }
        finally
        {
            _lock.Release();
        }
    }

    private string Correct(string sentence, CancellationToken token)
    {
        var promptTokens = Tokenize(ApplyTemplate(GrammarPrompt.Messages(sentence), addAssistant: true), addSpecial: true);
        var sentenceTokenCount = Tokenize(sentence, addSpecial: false).Length;
        var maxTokens = sentenceTokenCount * 2 + 16;

        _sampler.Reset();
        int position;
        try
        {
            position = Prefill(promptTokens);
        }
        catch
        {
            _cachedPrefix = [];
            throw;
        }

        var output = new List<byte>();
        var piece = new byte[256];
        var batch = new LLamaBatch();
        for (var i = 0; i < maxTokens; i++)
        {
            token.ThrowIfCancellationRequested();

            var next = _sampler.Sample(Native, -1);
            if (next.IsEndOfGeneration(_weights.Vocab)) break;

            var length = NativeApi.llama_token_to_piece(_weights.Vocab, next, piece, 0, false);
            if (length > 0) output.AddRange(piece.AsSpan(0, length).ToArray());

            // Output chỉ có một dòng: gặp xuống dòng sau khi đã có nội dung thì dừng sớm.
            if (output.Contains((byte)'\n') && Encoding.UTF8.GetString(output.ToArray()).Trim().Length > 0) break;

            batch.Clear();
            batch.Add(next, position++, Sequence, true);
            var result = Native.Decode(batch);
            if (result != DecodeResult.Ok)
            {
                _cachedPrefix = [];
                throw new GrammarEngineException(GrammarEngineErrorKind.DecodeFailed, ((int)result).ToString());
            }
        }

        return OutputSanitizer.Clean(Encoding.UTF8.GetString(output.ToArray()), sentence);
    }

    /// <summary>
    /// Đưa prompt vào KV cache, dùng lại phần prompt cố định (system + ví dụ) nếu đã có sẵn.
    /// Phần cố định chiếm phần lớn số token. Giữ nó trong KV cache giữa các lần gọi giúp mỗi lần kiểm tra
    /// chỉ phải xử lý phần câu mới.
    /// </summary>
    /// <returns>Vị trí (position) cho token tiếp theo.</returns>
    private int Prefill(LLamaToken[] promptTokens)
    {
        var start = 0;
        if (_cachedPrefix.Length > 0 && StartsWith(promptTokens, _cachedPrefix) && _cachedPrefix.Length < promptTokens.Length)
        {
            // Xoá phần sau prefix (câu cũ và output cũ), giữ lại prefix.
            Native.MemorySequenceRemove(Sequence, (LLamaPos)_cachedPrefix.Length, (LLamaPos)(-1));
            start = _cachedPrefix.Length;
        }
        else
        {
            Native.MemoryClear(true);
            _cachedPrefix = [];
            var prefix = FixedPrefixTokens();
            if (StartsWith(promptTokens, prefix) && prefix.Length < promptTokens.Length)
            {
                Decode(prefix, 0, logitsForLast: false);
                _cachedPrefix = prefix;
                start = prefix.Length;
            }
        }
        Decode(promptTokens.AsSpan(start), start, logitsForLast: true);
        return promptTokens.Length;
    }

    private void Decode(ReadOnlySpan<LLamaToken> tokens, int startPosition, bool logitsForLast)
    {
        var batch = new LLamaBatch();
        for (var offset = 0; offset < tokens.Length; offset += _batchSize)
        {
            batch.Clear();
            var chunk = tokens.Slice(offset, Math.Min(_batchSize, tokens.Length - offset));
            for (var i = 0; i < chunk.Length; i++)
            {
                var isLast = offset + i == tokens.Length - 1;
                batch.Add(chunk[i], startPosition + offset + i, Sequence, logitsForLast && isLast);
            }
            var result = Native.Decode(batch);
            if (result != DecodeResult.Ok)
                throw new GrammarEngineException(GrammarEngineErrorKind.DecodeFailed, ((int)result).ToString());
        }
    }

    /// <summary>Token của phần prompt không đổi giữa các câu: system prompt và các ví dụ mẫu.</summary>
    private LLamaToken[] FixedPrefixTokens()
    {
        if (_fixedPrefix is not null) return _fixedPrefix;
        var messages = GrammarPrompt.Messages("").SkipLast(1).ToList();
        return _fixedPrefix = Tokenize(ApplyTemplate(messages, addAssistant: false), addSpecial: true);
    }

    /// <summary>Dựng prompt bằng chat template của chính model (Qwen2.5 dùng ChatML).</summary>
    private string ApplyTemplate(IReadOnlyList<GrammarPrompt.Message> messages, bool addAssistant)
    {
        try
        {
            var template = new LLamaTemplate(_weights) { AddAssistant = addAssistant };
            foreach (var m in messages) template.Add(m.RoleName, m.Content);
            return Encoding.UTF8.GetString(template.Apply());
        }
        catch (Exception e)
        {
            throw new GrammarEngineException(GrammarEngineErrorKind.PromptTemplateFailed, null, e);
        }
    }

    private LLamaToken[] Tokenize(string text, bool addSpecial)
    {
        try
        {
            return Native.Tokenize(text, addSpecial, true, Encoding.UTF8);
        }
        catch (Exception e)
        {
            throw new GrammarEngineException(GrammarEngineErrorKind.TokenizeFailed, null, e);
        }
    }

    private static bool StartsWith(ReadOnlySpan<LLamaToken> tokens, ReadOnlySpan<LLamaToken> prefix)
    {
        if (prefix.Length > tokens.Length) return false;
        for (var i = 0; i < prefix.Length; i++)
            if (tokens[i] != prefix[i]) return false;
        return true;
    }

    public void Dispose()
    {
        _lock.Wait();
        try
        {
            if (_disposed) return;
            _disposed = true;
            _sampler.Dispose();
            _context.Dispose();
            _weights.Dispose();
        }
        finally
        {
            _lock.Release();
        }
    }
}
