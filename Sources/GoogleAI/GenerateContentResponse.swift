// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// The model's response to a generate content request.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct GenerateContentResponse {
  /// Token usage metadata for processing the generate content request.
  public struct UsageMetadata {
    /// The number of tokens in the request prompt.
    public let promptTokenCount: Int

    /// The total number of tokens across the generated response candidates.
    public let candidatesTokenCount: Int

    /// The total number of tokens in both the request and response.
    public let totalTokenCount: Int
  }

  /// A list of candidate response content, ordered from best to worst.
  public let candidates: [CandidateResponse]

  /// A value containing the safety ratings for the response, or, if the request was blocked, a
  /// reason for blocking the request.
  public let promptFeedback: PromptFeedback?

  /// Token usage metadata for processing the generate content request.
  public let usageMetadata: UsageMetadata?

  /// The response's content as text, if it exists.
  public var text: String? {
    guard let candidate = candidates.first else {
      Logging.default.error("Could not get text from a response that had no candidates.")
      return nil
    }
    let textValues: [String] = candidate.content.parts.compactMap { part in
      switch part {
      case let .text(text):
        return text
      case let .executableCode(executableCode):
        let codeBlockLanguage: String
        if executableCode.language == "LANGUAGE_UNSPECIFIED" {
          codeBlockLanguage = ""
        } else {
          codeBlockLanguage = executableCode.language.lowercased()
        }
        return "```\(codeBlockLanguage)\n\(executableCode.code)\n```"
      case let .codeExecutionResult(codeExecutionResult):
        if codeExecutionResult.output.isEmpty {
          return nil
        }
        return "```\n\(codeExecutionResult.output)\n```"
      case .data, .fileData, .functionCall, .functionResponse:
        return nil
      }
    }
    guard textValues.count > 0 else {
      Logging.default.error("Could not get a text part from the first candidate.")
      return nil
    }
    return textValues.joined(separator: "\n")
  }

  /// Returns function calls found in any `Part`s of the first candidate of the response, if any.
  public var functionCalls: [FunctionCall] {
    guard let candidate = candidates.first else {
      return []
    }
    return candidate.content.parts.compactMap { part in
      guard case let .functionCall(functionCall) = part else {
        return nil
      }
      return functionCall
    }
  }

  /// Initializer for SwiftUI previews or tests.
  public init(candidates: [CandidateResponse], promptFeedback: PromptFeedback? = nil,
              usageMetadata: UsageMetadata? = nil) {
    self.candidates = candidates
    self.promptFeedback = promptFeedback
    self.usageMetadata = usageMetadata
  }
}

/// A struct representing a possible reply to a content generation prompt. Each content generation
/// prompt may produce multiple candidate responses.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct CandidateResponse {
  /// The response's content.
  public let content: ModelContent

  /// The safety rating of the response content.
  public let safetyRatings: [SafetyRating]

  /// The reason the model stopped generating content, if it exists; for example, if the model
  /// generated a predefined stop sequence.
  public let finishReason: FinishReason?

  /// Cited works in the model's response content, if it exists.
  public let citationMetadata: CitationMetadata?
  
  /// The attribution information for sources that contributed to a grounded answer.
  public let groundingAttributions: [GroundingAttribution]

  /// The grounding metadata for the candidate.
  public let groundingMetadata: GroundingMetadata?
    
  /// Initializer for SwiftUI previews or tests.
  public init(content: ModelContent, safetyRatings: [SafetyRating], finishReason: FinishReason?,
              citationMetadata: CitationMetadata?, groundingAttributions: [GroundingAttribution], groundingMetadata: GroundingMetadata?) {
    self.content = content
    self.safetyRatings = safetyRatings
    self.finishReason = finishReason
    self.citationMetadata = citationMetadata
    self.groundingAttributions = groundingAttributions
    self.groundingMetadata = groundingMetadata
  }
}

/// A collection of source attributions for a piece of content.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct CitationMetadata {
  /// A list of individual cited sources and the parts of the content to which they apply.
  public let citationSources: [Citation]
}

/// The attribution for a source that contributed to an answer.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct GroundingAttribution {
    /// An identifier for the source contributing to this attribution.
    public let sourceId: AttributionSourceId
    
    /// The grounding source content that makes up this attribution.
    public let content: ModelContent
}

/// An identifier for the source contributing to this attribution.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public enum AttributionSourceId {
    /// An identifier for an inline passage.
    case groundingPassageId(GroundingPassage)
    
    /// An identifier for a Chunk fetched via Semantic Retriever.
    case semanticRetrieverChunk(SemanticRetrieverChunk)
    
    /// An unknown AttributionSourceID.
    case unknown
    
    /// An identifier for a part within a GroundingPassage.
    public struct GroundingPassage {
        /// The ID of the passage matching the GenerateAnswerRequest's GroundingPassage.id.
        public let passageId: String
        
        /// The index of the part within the GenerateAnswerRequest's GroundingPassage.content.
        public let partIndex: Int
    }

    /// An identifier for a Chunk retrieved via Semantic Retriever specified in the GenerateAnswerRequest using SemanticRetrieverConfig.
    public struct SemanticRetrieverChunk {
        /// The name of the source matching the request's SemanticRetrieverConfig.source.
        public let source: String
        
        /// The name of the Chunk containing the attributed text.
        public let chunk: String
    }
}

/// The metadata returned to client when grounding is enabled.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct GroundingMetadata {
    /// A list of supporting references retrieved from specified grounding source.
    public let groundingChunks: [GroundingChunk]
    
    /// A list of grounding support.
    public let groundingSupports: [GroundingSupport]
    
    /// The web search queries for the following-up web search.
    public let webSearchQueries: [String]
    
    /// The metadata related to retrieval in the grounding flow.
    public let retrievalMetadata: RetrievalMetadata
    
    /// A grounding chunk.
    public enum GroundingChunk {
        /// A grounding chunk from the web.
        case web(Web)
        
        /// A chunk from the web.
        public struct Web {
            /// The URI reference of the chunk.
            public let uri: String
            
            /// The title of the chunk.
            public let title: String
        }
    }
    
    /// A grounding support.
    public struct GroundingSupport {
        /// A list of indices (into 'groundingChunk') specifying the citations associated with the claim. For instance [1,3,4] means that groundingChunk[1], groundingChunk[3], groundingChunk[4] are the retrieved content attributed to the claim.
        public let groundingChunkIndices: [Int]
        
        /// The confidence scores of the support references. Ranges from 0 to 1. 1 is the most confident. This list must have the same size as the groundingChunkIndices.
        public let confidenceScores: [Float]
        
        /// A segment of the content this support belongs to.
        public let segment: ContentSegment
    }
    
    /// The metadata related to retrieval in the grounding flow.
    public struct RetrievalMetadata {
        /// Score indicating how likely information from google search could help answer the prompt. The score is in the range [0, 1], where 0 is the least likely and 1 is the most likely. This score is only populated when google search grounding and dynamic retrieval is enabled. It will be compared to the threshold to determine whether to trigger google search.
        public let googleSearchDynamicRetrievalScore: Float?
    }
}

/// A struct describing a source attribution.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct Citation {
  /// The inclusive beginning of a sequence in a model response that derives from a cited source.
  public let startIndex: Int

  /// The exclusive end of a sequence in a model response that derives from a cited source.
  public let endIndex: Int

  /// A link to the cited source.
  public let uri: String

  /// The license the cited source work is distributed under, if specified.
  public let license: String?
}

/// A value enumerating possible reasons for a model to terminate a content generation request.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public enum FinishReason: String {
  case unknown = "FINISH_REASON_UNKNOWN"

  case unspecified = "FINISH_REASON_UNSPECIFIED"

  /// Natural stop point of the model or provided stop sequence.
  case stop = "STOP"

  /// The maximum number of tokens as specified in the request was reached.
  case maxTokens = "MAX_TOKENS"

  /// The token generation was stopped because the response was flagged for safety reasons.
  /// NOTE: When streaming, the Candidate.content will be empty if content filters blocked the
  /// output.
  case safety = "SAFETY"

  /// The token generation was stopped because the response was flagged for unauthorized citations.
  case recitation = "RECITATION"

  /// All other reasons that stopped token generation.
  case other = "OTHER"
}

/// A metadata struct containing any feedback the model had on the prompt it was provided.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct PromptFeedback {
  /// A type describing possible reasons to block a prompt.
  public enum BlockReason: String {
    /// The block reason is unknown.
    case unknown = "UNKNOWN"

    /// The block reason was not specified in the server response.
    case unspecified = "BLOCK_REASON_UNSPECIFIED"

    /// The prompt was blocked because it was deemed unsafe.
    case safety = "SAFETY"

    /// All other block reasons.
    case other = "OTHER"
  }

  /// The reason a prompt was blocked, if it was blocked.
  public let blockReason: BlockReason?

  /// The safety ratings of the prompt.
  public let safetyRatings: [SafetyRating]

  /// Initializer for SwiftUI previews or tests.
  public init(blockReason: BlockReason?, safetyRatings: [SafetyRating]) {
    self.blockReason = blockReason
    self.safetyRatings = safetyRatings
  }
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GenerateContentResponse: Decodable {
  enum CodingKeys: CodingKey {
    case candidates
    case promptFeedback
    case usageMetadata
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard container.contains(CodingKeys.candidates) || container
      .contains(CodingKeys.promptFeedback) else {
      let context = DecodingError.Context(
        codingPath: [],
        debugDescription: "Failed to decode GenerateContentResponse;" +
          " missing keys 'candidates' and 'promptFeedback'."
      )
      throw DecodingError.dataCorrupted(context)
    }

    if let candidates = try container.decodeIfPresent(
      [CandidateResponse].self,
      forKey: .candidates
    ) {
      self.candidates = candidates
    } else {
      candidates = []
    }
    promptFeedback = try container.decodeIfPresent(PromptFeedback.self, forKey: .promptFeedback)
    usageMetadata = try container.decodeIfPresent(UsageMetadata.self, forKey: .usageMetadata)
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GenerateContentResponse.UsageMetadata: Decodable {
  enum CodingKeys: CodingKey {
    case promptTokenCount
    case candidatesTokenCount
    case totalTokenCount
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    promptTokenCount = try container.decodeIfPresent(Int.self, forKey: .promptTokenCount) ?? 0
    candidatesTokenCount = try container
      .decodeIfPresent(Int.self, forKey: .candidatesTokenCount) ?? 0
    totalTokenCount = try container.decodeIfPresent(Int.self, forKey: .totalTokenCount) ?? 0
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CandidateResponse: Decodable {
  enum CodingKeys: CodingKey {
    case content
    case safetyRatings
    case finishReason
    case finishMessage
    case citationMetadata
    case groundingAttributions
    case groundingMetadata
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    do {
      if let content = try container.decodeIfPresent(ModelContent.self, forKey: .content) {
        self.content = content
      } else {
        content = ModelContent(parts: [])
      }
    } catch {
      // Check if `content` can be decoded as an empty dictionary to detect the `"content": {}` bug.
      if let content = try? container.decode([String: String].self, forKey: .content),
         content.isEmpty {
        throw InvalidCandidateError.emptyContent(underlyingError: error)
      } else {
        throw InvalidCandidateError.malformedContent(underlyingError: error)
      }
    }

    if let safetyRatings = try container.decodeIfPresent(
      [SafetyRating].self,
      forKey: .safetyRatings
    ) {
      self.safetyRatings = safetyRatings
    } else {
      safetyRatings = []
    }

    finishReason = try container.decodeIfPresent(FinishReason.self, forKey: .finishReason)

    citationMetadata = try container.decodeIfPresent(
      CitationMetadata.self,
      forKey: .citationMetadata
    )
      
    if let groundingAttributions = try container.decodeIfPresent([GroundingAttribution].self, forKey: .groundingAttributions) {
      self.groundingAttributions = groundingAttributions
    } else {
      self.groundingAttributions = []
    }
      
    groundingMetadata = try container.decodeIfPresent(GroundingMetadata.self, forKey: .groundingMetadata)
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CitationMetadata: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingAttribution: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension AttributionSourceId: Decodable {
    enum CodingKeys: CodingKey {
        case groundingPassageId
        case semanticRetrieverChunk
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let groundingPassage = try container.decodeIfPresent(GroundingPassage.self, forKey: .groundingPassageId) {
            self = .groundingPassageId(groundingPassage)
        } else if let semanticRetrieverChunk = try container.decodeIfPresent(SemanticRetrieverChunk.self, forKey: .semanticRetrieverChunk) {
            self = .semanticRetrieverChunk(semanticRetrieverChunk)
        } else {
            Logging.default.error("[GoogleGenerativeAI] AttributionSourceID is neither a GroundingPassageId nor a SemanticRetrieverChunk.")
            self = .unknown
        }
    }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension AttributionSourceId.GroundingPassage: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension AttributionSourceId.SemanticRetrieverChunk: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata.GroundingChunk: Decodable {
    enum CodingKeys: CodingKey {
        case web
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = .web(try container.decode(Web.self, forKey: .web))
    }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata.GroundingChunk.Web: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata.GroundingSupport: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata.RetrievalMetadata: Decodable {
    enum CodingKeys: CodingKey {
        case googleSearchDynamicRetrievalScore
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        googleSearchDynamicRetrievalScore = try container.decodeIfPresent(Float.self, forKey: .googleSearchDynamicRetrievalScore)
    }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension Citation: Decodable {
  enum CodingKeys: CodingKey {
    case startIndex
    case endIndex
    case uri
    case license
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    startIndex = try container.decodeIfPresent(Int.self, forKey: .startIndex) ?? 0
    endIndex = try container.decode(Int.self, forKey: .endIndex)
    uri = try container.decode(String.self, forKey: .uri)
    if let license = try container.decodeIfPresent(String.self, forKey: .license),
       !license.isEmpty {
      self.license = license
    } else {
      license = nil
    }
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension FinishReason: Decodable {
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let decodedFinishReason = FinishReason(rawValue: value) else {
      Logging.default
        .error("[GoogleGenerativeAI] Unrecognized FinishReason with value \"\(value)\".")
      self = .unknown
      return
    }

    self = decodedFinishReason
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension PromptFeedback.BlockReason: Decodable {
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let decodedBlockReason = PromptFeedback.BlockReason(rawValue: value) else {
      Logging.default
        .error("[GoogleGenerativeAI] Unrecognized BlockReason with value \"\(value)\".")
      self = .unknown
      return
    }

    self = decodedBlockReason
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension PromptFeedback: Decodable {
  enum CodingKeys: CodingKey {
    case blockReason
    case safetyRatings
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    blockReason = try container.decodeIfPresent(
      PromptFeedback.BlockReason.self,
      forKey: .blockReason
    )
    if let safetyRatings = try container.decodeIfPresent(
      [SafetyRating].self,
      forKey: .safetyRatings
    ) {
      self.safetyRatings = safetyRatings
    } else {
      safetyRatings = []
    }
  }
}

// MARK: Equatable Conformance

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GenerateContentResponse: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GenerateContentResponse.UsageMetadata: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CandidateResponse: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CitationMetadata: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingAttribution: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension AttributionSourceId: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension AttributionSourceId.GroundingPassage: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension AttributionSourceId.SemanticRetrieverChunk: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata.GroundingChunk: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata.GroundingChunk.Web: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata.GroundingSupport: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GroundingMetadata.RetrievalMetadata: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension Citation: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension FinishReason: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension PromptFeedback.BlockReason: Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension PromptFeedback: Equatable {}
