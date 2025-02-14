# lambda_function.py
import base64
import gzip
import json
import boto3
import os
import logging

eventbridge = boto3.client('events')


EVENT_BUS_NAME = os.environ.get('EVENT_BUS_NAME', 'default')

class StructuredMessage:
    def __init__(self, message, /, **kwargs):
        self.message = message
        self.kwargs = kwargs

    def __str__(self):
        return '%s >>> %s' % (self.message, json.dumps(self.kwargs))

_ = StructuredMessage # optional, to improve readability
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

def handler(event, context):
    # CloudWatch Logs 구독 이벤트는 'awslogs' 키에 base64 인코딩된 gzip 데이터가 있음
    cw_data = event['awslogs']['data']
    compressed_payload = base64.b64decode(cw_data)
    uncompressed_payload = gzip.decompress(compressed_payload)
    payload = json.loads(uncompressed_payload)
    
    for log_event in payload['logEvents']:
        logger.info('handling log_event', log_event)
        try:
            message = json.loads(log_event['message'])
        except Exception as e:
            message = log_event['message']
        
        try:
            # EventBridge로 전달 (여기서는 기본 이벤트 버스 사용)
            response = eventbridge.put_events(
                Entries=[
                    {
                        'Source': 'custom.cloudtrail',
                        'DetailType': 'CloudTrail Log',
                        'Detail': json.dumps(message),
                        'EventBusName': EVENT_BUS_NAME
                    },
                ]
            )
        except Exception as e:
            logger.error(_(e))
            raise(e)
    return {
        'statusCode': 200,
        'body': 'Processed {} log events'.format(len(payload.get('logEvents', [])))
    }


# ELBV2_CLIENT = boto3.client('elbv2')

# TARGET_GROUP_ARN = os.environ['TARGET_GROUP_ARN']

# def handler(event, context):
#     # Only modify on CreateNetworkInterface events
#     if event["detail"]["eventName"] == "CreateNetworkInterface":
#         ip = event['detail']['responseElements']['networkInterface']['privateIpAddress']

#         # Add the extracted private IP address of the ENI as an IP target in the target group
#         try:
#             logger.info('IP address %s is identified as belonging to one of the cluster endpoint ENIs', ip)
#             response = ELBV2_CLIENT.register_targets(
#                 TargetGroupArn = TARGET_GROUP_ARN,
#                 Targets=[{
#                     'Id': ip,
#                     'Port': 443
#                 }]
#             )
#             logger.info(_(response))
#         except Exception as e:
#             logger.error(_(e))
#             raise(e)
