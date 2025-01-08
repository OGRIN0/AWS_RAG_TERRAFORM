data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "project-dev-lambda-function-code"
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "project-dev-lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_policy" "lambda_policy" {
  name = "project-dev-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.lambda_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.lambda_bucket.bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "aws_iam_policy_document" "example_agent_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["bedrock.amazonaws.com"]
      type        = "Service"
    }
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "aws:SourceAccount"
    }
    condition {
      test     = "ArnLike"
      values   = ["arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agent/*"]
      variable = "AWS:SourceArn"
    }
  }
}

resource "aws_iam_role" "bedrock_agent_role" {
  name               = "project-dev-bedrock-agent-role"
  assume_role_policy = data.aws_iam_policy_document.example_agent_trust.json
}

resource "aws_iam_policy" "bedrock_agent_policy" {
  name = "project-dev-bedrock-agent-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["bedrock:*"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["aoss:Search", "aoss:BatchGetCollection", "aoss:DescribeCollection"],
        Resource = "arn:aws:aoss:us-east-1:340752796889:collection/ssgjrqcwqgoo8cb1xj25"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_policy_attach" {
  role       = aws_iam_role.bedrock_agent_role.name
  policy_arn = aws_iam_policy.bedrock_agent_policy.arn
}

data "aws_iam_policy_document" "kb_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "kb_role" {
  name               = "project-dev-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_assume_role_policy.json
}

resource "aws_iam_policy" "kb_policy" {
  name = "project-dev-kb-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.lambda_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.lambda_bucket.bucket}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
          "aoss:CreateVectorIndex",
          "aoss:UpdateVectorIndex",
          "aoss:DeleteVectorIndex",
          "aoss:BatchPutDocument",
          "aoss:BatchDeleteDocument",
          "aoss:Search",
          "aoss:ListCollections",
          "aoss:DescribeCollection"
        ],
        Resource = "arn:aws:aoss:*:*:collection/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kb_policy_attach" {
  role       = aws_iam_role.kb_role.name
  policy_arn = aws_iam_policy.kb_policy.arn
}


resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name        = "pdf-processing-encryption-policy"
  type        = "encryption"
  description = "Encryption policy for the PDF processing collection"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection",
        Resource     = ["collection/pdf-processing-collection"]
      }
    ],
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_collection" "pdf_processing" {
  name        = "pdf-processing-collection"
  depends_on = [aws_opensearchserverless_security_policy.encryption_policy]
}

# resource "aws_bedrockagent_knowledge_base" "pdf_processing_kb" {
#   name     = "pdf-processing-kb"
#   role_arn = aws_iam_role.kb_role.arn

#   knowledge_base_configuration {
#     vector_knowledge_base_configuration {
#       embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
#     }
#     type = "VECTOR"
#   }

#   storage_configuration {
#     type = "OPENSEARCH_SERVERLESS"
#     opensearch_serverless_configuration {
#       collection_arn    = "arn:aws:aoss:us-east-1:340752796889:collection/ssgjrqcwqgoo8cb1xj25"
#       vector_index_name = "pdf-processing-collection"
#       field_mapping {
#         vector_field   = "embedding_field"
#         text_field     = "content"
#         metadata_field = "tags"
# }
#     }
#   }
# }

resource "aws_bedrockagent_agent" "pdf_processing_agent" {
  agent_name                  = "project-dev-pdf-processing-agent"
  foundation_model            = "amazon.nova-pro-v1:0"
  idle_session_ttl_in_seconds = 500
  prepare_agent               = true
  skip_resource_in_use_check  = false
  instruction = jsonencode({
    "task" : "process-pdf",
    "description" : "This agent processes PDF files for OCR and extraction"
  })
  agent_resource_role_arn = aws_iam_role.bedrock_agent_role.arn
}

resource "aws_bedrockagent_agent_knowledge_base_association" "kb_association" {
  agent_id             = aws_bedrockagent_agent.pdf_processing_agent.id
  description          = "Knowledge base for PDF processing agent"
  knowledge_base_id    = "VP7UQPW45M"
  knowledge_base_state = "ENABLED"
}
