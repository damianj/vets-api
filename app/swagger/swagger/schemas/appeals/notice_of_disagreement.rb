# frozen_string_literal: true

require 'decision_review/schemas'
module Swagger
  module Schemas
    module Appeals
      class NoticeOfDisagreement
        include Swagger::Blocks

        swagger_schema(
          'nodContestableIssues',
          DecisionReview::Schemas::NOD_CONTESTABLE_ISSUES_RESPONSE_200.merge(
            example: {
              'data' => [
                {
                  'type' => 'contestableIssue',
                  'id' => 'string',
                  'attributes' => {
                    'ratingIssueReferenceId' => 'string',
                    'ratingIssueProfileDate' => '2020-08-31',
                    'ratingIssueDiagnosticCode' => 'string',
                    'ratingDecisionReferenceId' => 'string',
                    'decisionIssueId' => 0,
                    'approxDecisionDate' => '2020-08-31',
                    'description' => 'string',
                    'rampClaimId' => 'string',
                    'titleOfActiveReview' => 'string',
                    'sourceReviewType' => 'string',
                    'timely' => true,
                    'latestIssuesInChain' => [{ 'id' => 19, 'approxDecisionDate' => '2020-08-31' }],
                    'ratingIssueSubjectText' => 'string',
                    'ratingIssuePercentNumber' => 'string',
                    'isRating' => true
                  }
                }
              ]
            }
          ).except('$schema')
        )
      end
    end
  end
end
