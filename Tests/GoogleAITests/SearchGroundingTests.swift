//
//  SearchGroundingTests.swift
//  generative-ai-swift
//
//  Created by Oscar Mann on 9/4/2025.
//

import Foundation
@testable import GoogleGenerativeAI
import XCTest

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
final class SearchGroundingTests: XCTestCase {
    let decoder = JSONDecoder()
    let role = "test-role"
    let answer = "test-answer"
    let promptTokens = 53
    let candidatesTokens = 26
    let uri = "test-uri"
    let id = "test-id"
    let text = "test-text"
    let chunk = "test-chunk"
    
    func testEncode_allFieldsIncluded() throws {
        let content = try ModelContent(role: role, answer)
        let segment = ContentSegment(
            partIndex: 0,
            startIndex: 2,
            endIndex: 13,
            text: text
        )
        let safetyRating = SafetyRating(
            category: .dangerousContent,
            probability: .medium
        )
        
        let response = GenerateContentResponse(
            candidates: [
                CandidateResponse(
                    content: content,
                    safetyRatings: [safetyRating],
                    finishReason: .safety,
                    citationMetadata: CitationMetadata(
                        citationSources: [
                            Citation(
                                startIndex: 2,
                                endIndex: 13,
                                uri: uri,
                                license: "CC0"
                            )
                        ]
                    ),
                    groundingAttributions: [
                        GroundingAttribution(
                            sourceId: .groundingPassageId(AttributionSourceId.GroundingPassage(
                                passageId: id,
                                partIndex: 0
                            )),
                            content: content
                        ),
                        GroundingAttribution(
                            sourceId: .semanticRetrieverChunk(AttributionSourceId.SemanticRetrieverChunk(source: text, chunk: chunk)),
                            content: content
                        )
                    ],
                    groundingMetadata: GroundingMetadata(
                        groundingChunks: [
                            GroundingMetadata.GroundingChunk.web(.init(uri: uri, title: text))
                        ],
                        groundingSupports: [
                            GroundingMetadata.GroundingSupport(
                                groundingChunkIndices: [0],
                                confidenceScores: [1],
                                segment: segment
                            )
                        ],
                        webSearchQueries: [answer],
                        retrievalMetadata: GroundingMetadata.RetrievalMetadata(googleSearchDynamicRetrievalScore: 1)
                    )
                )
            ],
            promptFeedback: PromptFeedback(
                blockReason: .safety,
                safetyRatings: [safetyRating]
            ),
            usageMetadata: GenerateContentResponse.UsageMetadata(
                promptTokenCount: promptTokens,
                candidatesTokenCount: candidatesTokens,
                totalTokenCount: promptTokens + candidatesTokens
            )
        )
        
        let json = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "\(answer)"
                  }
                ],
                "role": "\(role)"
              },
              "finishReason": "SAFETY",
              "safetyRatings": [
                {
                  "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                  "probability": "MEDIUM"
                }
              ],
              "citationMetadata": {
                "citationSources": [
                  {
                    "startIndex": 2,
                    "endIndex": 13,
                    "uri": "\(uri)",
                    "license": "CC0"
                  }
                ]
              },
              "groundingAttributions": [
                {
                  "sourceId": {
                    "groundingPassageId": {
                      "passageId": "\(id)",
                      "partIndex": 0
                    }
                  },
                  "content": {
                    "parts": [
                      {
                        "text": "\(answer)"
                      }
                    ],
                    "role": "\(role)"
                  }
                },
                {
                  "sourceId": {
                    "semanticRetrieverChunk": {
                      "source": "\(text)",
                      "chunk": "\(chunk)"
                    }
                  },
                  "content": {
                      "parts": [
                      {
                          "text": "\(answer)"
                      }
                      ],
                      "role": "\(role)"
                  }
                }
              ],
              "groundingMetadata": {
                "groundingChunks": [
                  {
                    "web": {
                      "uri": "\(uri)",
                      "title": "\(text)"
                    }
                  }
                ],
                "groundingSupports": [
                  {
                    "segment": {
                      "partIndex": 0,
                      "startIndex": 2,
                      "endIndex": 13,
                      "text": "\(text)"
                    },
                    "groundingChunkIndices": [
                      0
                    ],
                    "confidenceScores": [
                      1
                    ]
                  }
                ],
                "retrievalMetadata": {
                  "googleSearchDynamicRetrievalScore": 1
                },
                "webSearchQueries": [
                  "\(answer)"
                ]
              }
            }
          ],
          "promptFeedback": {
            "blockReason": "SAFETY",
            "safetyRatings": [
              {
                "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                "probability": "MEDIUM"
              }
            ]
          },
          "usageMetadata": {
            "promptTokenCount": \(promptTokens),
            "candidatesTokenCount": \(candidatesTokens),
            "totalTokenCount": \(promptTokens + candidatesTokens),
            "promptTokensDetails": [
              {
                "modality": "TEXT",
                "tokenCount": \(promptTokens)
              }
            ],
            "candidatesTokensDetails": [
              {
                "modality": "TEXT",
                "tokenCount": \(candidatesTokens)
              }
            ]
          },
          "modelVersion": "gemini-2.0-flash"
        }    
        """
        
        let jsonData = try XCTUnwrap(json.data(using: .utf8))
        let decodedResponse = try decoder.decode(GenerateContentResponse.self, from: jsonData)
        
        XCTAssertEqual(decodedResponse, response)
    }
}
