import Cocoa
import FlutterMacOS
import NaturalLanguage

/// macOS 语义 NLP 插件
/// 使用 Natural Language 框架进行语义分析
class SemanticNlpPlugin: NSObject, FlutterPlugin {
    
    private var channel: FlutterMethodChannel?
    
    // 功德福德类关键词（高权重 = 3.0）
    private let meritKeywords: Set<String> = [
        "功德", "福德", "福报", "福慧", "善根", "善业",
        "灭罪", "消业", "除障", "离苦", "解脱", "往生", "成佛",
        "善报", "福田", "增益", "加持", "护佑", "灭除"
    ]
    
    // 利益描述类关键词（中高权重 = 2.5）
    private let benefitKeywords: Set<String> = [
        "能除", "能灭", "能消", "能得", "能令", "能使",
        "悉皆", "一切", "无量", "不可思议", "无边", "无数",
        "速得", "即得", "当得", "必得", "皆得"
    ]
    
    // 赞扬赞叹类关键词（中权重 = 2.0）
    private let praiseKeywords: Set<String> = [
        "希有", "善哉", "难得", "殊胜", "微妙", "清净",
        "威神", "神力", "庄严", "圆满", "广大", "甚深",
        "第一", "无上", "最胜", "真实", "究竟"
    ]
    
    // 佛法宝类关键词（低权重 = 1.5）
    private let dharmaKeywords: Set<String> = [
        "如来", "世尊", "菩萨", "般若", "涅槃",
        "真言", "陀罗尼", "三昧", "菩提", "法门"
    ]
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.fabushi.app/semantic_nlp",
            binaryMessenger: registrar.messenger
        )
        let instance = SemanticNlpPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            // Natural Language 框架无需初始化
            result(true)
            
        case "analyzeSentences":
            if let args = call.arguments as? [String: Any],
               let sentences = args["sentences"] as? [String] {
                let scored = analyzeSentences(sentences)
                result(scored)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "需要 sentences 参数", details: nil))
            }
            
        case "getSimilarity":
            if let args = call.arguments as? [String: Any],
               let text1 = args["text1"] as? String,
               let text2 = args["text2"] as? String {
                let similarity = calculateSimilarity(text1, text2)
                result(similarity)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "需要 text1 和 text2 参数", details: nil))
            }
            
        case "dispose":
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 分析句子
    
    private func analyzeSentences(_ sentences: [String]) -> [[String: Any]] {
        var results: [[String: Any]] = []
        
        for (index, sentence) in sentences.enumerated() {
            let score = calculateScore(for: sentence)
            results.append([
                "text": sentence,
                "score": score,
                "originalIndex": index
            ])
        }
        
        // 按分数降序排序
        results.sort { ($0["score"] as? Double ?? 0) > ($1["score"] as? Double ?? 0) }
        
        return results
    }
    
    // MARK: - 计算分数
    
    private func calculateScore(for sentence: String) -> Double {
        var score = 0.0
        var matchCount = 0
        
        // 使用 Natural Language 框架进行分词
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = sentence
        
        var tokens: [String] = []
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex,
                            unit: .word,
                            scheme: .tokenType) { _, range in
            tokens.append(String(sentence[range]))
            return true
        }
        
        // 检查关键词匹配
        for token in tokens {
            if meritKeywords.contains(token) {
                score += 3.0
                matchCount += 1
            } else if benefitKeywords.contains(token) {
                score += 2.5
                matchCount += 1
            } else if praiseKeywords.contains(token) {
                score += 2.0
                matchCount += 1
            } else if dharmaKeywords.contains(token) {
                score += 1.5
                matchCount += 1
            }
        }
        
        // 检查复合词（分词可能无法识别的短语）
        for keyword in meritKeywords {
            if sentence.contains(keyword) && !tokens.contains(keyword) {
                score += 3.0
                matchCount += 1
            }
        }
        for keyword in benefitKeywords {
            if sentence.contains(keyword) && !tokens.contains(keyword) {
                score += 2.5
                matchCount += 1
            }
        }
        for keyword in praiseKeywords {
            if sentence.contains(keyword) && !tokens.contains(keyword) {
                score += 2.0
                matchCount += 1
            }
        }
        for keyword in dharmaKeywords {
            if sentence.contains(keyword) && !tokens.contains(keyword) {
                score += 1.5
                matchCount += 1
            }
        }
        
        // 多匹配加成
        if matchCount > 1 {
            score *= 1.0 + Double(matchCount - 1) * 0.2
        }
        
        // 长度调整
        if sentence.count < 10 {
            score *= 0.8
        } else if sentence.count > 50 {
            score *= 0.9
        }
        
        return score
    }
    
    // MARK: - 计算相似度
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        // 使用 NLEmbedding 计算语义相似度（如果可用）
        if #available(macOS 10.15, *) {
            if let embedding = NLEmbedding.sentenceEmbedding(for: .simplifiedChinese) {
                if let v1 = embedding.vector(for: text1),
                   let v2 = embedding.vector(for: text2) {
                    return cosineSimilarity(v1, v2)
                }
            }
            // 尝试繁体中文
            if let embedding = NLEmbedding.sentenceEmbedding(for: .traditionalChinese) {
                if let v1 = embedding.vector(for: text1),
                   let v2 = embedding.vector(for: text2) {
                    return cosineSimilarity(v1, v2)
                }
            }
        }
        
        // 降级：使用简单的 Jaccard 相似度
        let set1 = Set(text1)
        let set2 = Set(text2)
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
    
    // MARK: - 余弦相似度
    
    private func cosineSimilarity(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count, !v1.isEmpty else { return 0.0 }
        
        var dot = 0.0
        var mag1 = 0.0
        var mag2 = 0.0
        
        for i in 0..<v1.count {
            dot += v1[i] * v2[i]
            mag1 += v1[i] * v1[i]
            mag2 += v2[i] * v2[i]
        }
        
        guard mag1 > 0, mag2 > 0 else { return 0.0 }
        return dot / (sqrt(mag1) * sqrt(mag2))
    }
}
