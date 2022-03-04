openapi: 3.0.0
info:
  title: IFC Call Quality API
  description: REST API for IFC Call Quality Project
  version: 1.0.0
servers:
  - url: https://jnvndc9s5l-vpce-0128b8cb177b44544.execute-api.ca-central-1.amazonaws.com/dev
    description: DEV server
  - url: https://jvhxjw6sjh-vpce-0128b8cb177b44544.execute-api.ca-central-1.amazonaws.com/intg
    description: INTG server
  - url: https://xevlow1seb-vpce-0128b8cb177b44544.execute-api.ca-central-1.amazonaws.com/uat
    description: UAT server
  - url: https://42lij0eng2-vpce-05f63fb27d1912426.execute-api.ca-central-1.amazonaws.com/prod
    description: Production server
components:
  securitySchemes:
    bearerAuth:
      type: apiKey
      description: Bearer token containing JWT to be passed in http header
      name: Authorization
      in: header
      x-amazon-apigateway-authtype: custom
      x-amazon-apigateway-authorizer:
        type: request
        identitySource: method.request.header.Cookie
        authorizerCredentials: ${apigateway_role}
        authorizerUri: arn:aws:apigateway:${region}:lambda:path/2015-03-31/functions/${authorizer_arn}/invocations
        authorizerResultTtlInSeconds: ${authorizer_ttl}
  schemas:
    LogError:
      type: object
      properties:
        status:
          type: string
        message:
          type: string
        stack:
          type: string
        timestamp:
          type: number
      required:
        - status
        - message
security:
  - bearerAuth: [ ]
paths:   
  /logerrors:
    post:
      description: Store a UI Logs information
      tags:
        - UIlogerror
      requestBody:
        description: requested LogError information
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/LogError'
      responses:
        '200':
          description: Available Log error
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: string
            Access-Control-Allow-Methods:
              schema:
                type: string
            Access-Control-Allow-Credentials:
              schema:
                type: string
            Access-Control-Allow-Headers:
              schema:
                type: string
            Cache-Control:
              schema:
                type: string
                default: "no-cache,no-store,max-age=0,s-maxage=0,must-revalidate"
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/LogError'
      x-amazon-apigateway-integration:
          uri: arn:aws:apigateway:ca-central-1:logs:action/PutLogEvents
          passthroughBehavior: when_no_match
          httpMethod: POST
          credentials: arn:aws:iam::761944119947:role/api_gateway_cloudwatch_global
          type: aws
          responses:
            default:
              statusCode: 200
              responseTemplates:
                application/json: '{"message": "success"}'
          requestParameters:
            integration.request.header.Content-Type: "'application/x-amz-json-1.1'"
            integration.request.header.X-Amz-Target: "'Logs_20140328.PutLogEvents'"
          requestTemplates:
            application/json: '{
                "logEvents": [
                    {
                      "message": $input.json("$.message"),
                      "timestamp": $input.json("$.timestamp")
                    }
                ],
                "logGroupName":  "${log_group}",
                "logStreamName": "${log_stream}"
            }'
    options:
      tags:
        - Options
      security: [ ]   # No security
      responses:
        '200':
          description: Empty options
          headers:
            Access-Control-Allow-Origin:
              schema:
                type: string
            Access-Control-Allow-Methods:
              schema:
                type: string
            Access-Control-Allow-Headers:
              schema:
                type: string
            Access-Control-Allow-Credentials:
              schema:
                type: string
            Cache-Control:
              schema:
                type: string
                default: "no-cache,no-store,max-age=0,s-maxage=0,must-revalidate"
      x-amazon-apigateway-integration:
        responses:
          default:
            statusCode: 200
            responseParameters:
              method.response.header.Access-Control-Allow-Headers: '''Content-Type,X-Amz-Date,Authorization,Identity,X-Api-Key'''
              method.response.header.Access-Control-Allow-Methods: '''*'''
              method.response.header.Access-Control-Allow-Origin: '''${origin_domain}'''
              method.response.header.Access-Control-Allow-Credentials: '''true'''
              method.response.header.Cache-Control: '''no-cache,no-store,max-age=0,s-maxage=0,must-revalidate'''
            responseTemplates:
              application/json: |
                {}
        requestTemplates:
          application/json: "{\"statusCode\": 200}"
        passthroughBehavior: when_no_match
        type: mock
x-amazon-apigateway-request-validators:
  all:
    validateRequestBody: true
    validateRequestParameters: true
  params-only:
    validateRequestBody: false
    validateRequestParameters: true
x-amazon-apigateway-request-validator: all
x-amazon-apigateway-gateway-responses:
  DEFAULT_4XX:
    responseParameters:
      gatewayresponse.header.Access-Control-Allow-Origin: '''${origin_domain}'''
      gatewayresponse.header.Access-Control-Allow-Credentials: '''true'''
    responseTemplates:
      application/json: '{"message":$context.error.messageString}'
  DEFAULT_5XX:
    responseParameters:
      gatewayresponse.header.Access-Control-Allow-Origin: '''${origin_domain}'''
      gatewayresponse.header.Access-Control-Allow-Credentials: '''true'''
    responseTemplates:
      application/json: '{"message":$context.error.messageString}'
