# /*
# * Copyright 2023 Google LLC
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *     https://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# */

# This is a function that calls this API
# https://github.com/bundesAPI/entgeltatlas-api

# # This is an example of what the API returns
# api_result = [
#     {
#         "kldb": "84304",
#         "region": {
#             "id": 1,
#             "bezeichnung": "Deutschland",
#             "schluessel": "D",
#             "oberRegionId": None,
#             "oberRegionBezeichnung": None,
#             "beitragsBemessungsGrenze": 6700
#         },
#         "gender": {
#             "id": 3,
#             "bezeichnung": "Frauen"
#         },
#         "ageCategory": {
#             "id": 1,
#             "bezeichnung": "Gesamt"
#         },
#         "performanceLevel": {
#             "id": 4,
#             "bezeichnung": "Experte"
#         },
#         "branche": {
#             "id": 1,
#             "bezeichnung": "Gesamt"
#         },
#         "entgelt": 4982,
#         "entgeltQ25": 4295,
#         "entgeltQ75": 5829,
#         "besetzung": 42478
#     }
# ]

import functions_framework
import requests
from flask import jsonify
from google.cloud import logging

@functions_framework.http
def process_request(request):
    try:
        logger = logging.Client().logger("cf_entgeltatlas")

        request_json = request.get_json()

        # the function should be implemented in a way that receives a batch of calls. Each element in the calls array is 1 record-level invocation in BQ SQL
        calls = request_json['calls']

        # 'calls' is an array of arrays where each element corresponds to one function invocation from bq with its paramaters
        # bq will try to batch multiple calls to the cloud function to enhance performance and the function should be able to handle those
        # remote function batch settings are configured while creating the function definition on BQ
        calls_count = len(calls)
        logger.log_text(
            f"Received {calls_count} calls from BQ. Calls: " + str(calls),
            severity="INFO"
        )

        replies = []
        for call in calls:

            logger.log_text(
                f"Will process bq call " + str(call),
                severity="INFO"
            )

            # Classification of Occupations [KldB-Key]
            # https://www.klassifikationsserver.de/klassService/jsp/common/url.jsf?item=8430&variant=kldb2010&detail=true

            # performance level: 1=helper; 2=skilled worker; 3=Specialist 4=Expert.

            # Gender: 1=total, 2=men, 3=women

            # Age: 1=Total; 2=under 25; 3=25 to under 55; 4=from 55

            # Branch: 1=total; 2=agriculture and forestry, fisheries; 3=manufacturing industry without construction; 4=construction; 5=trade, transport, warehousing and hospitality; 6=information and communication; 7=finance and insurance industry; 8=real estate and housing; 9=provision economic Services; 10=Public administration, school, health, social affairs; 11=other services
            # https://rest.arbeitsagentur.de/infosysbub/entgeltatlas/pc/v1/branchen

            # Region: 1=Germany; 2=East Germany; 3=West Germany; 11=BaWü; 12=Bavaria; 14=Berlin; 15=Brandenburg; 7=Bremen; 5=Hamburg; 9=Hessen; 16=Mecklenburg-Western Pomerania; 6=Lower Saxony; 8=North Rhine-Westphalia; 10=Rhineland-Palatinate; 13=Saarland; 17=Saxony; 18=Saxony-Anhalt; 4=Schleswig-Holstein; 19=Thuringia; 22=Dortmund; 20=Dresden; 21=Dusseldorf; 23=food; 24=Frankfurt am Main; 26=Hanover; 27=Cologne; 28=Leipzig; 29=Munich; 25=Nuremberg; 30=Stuttgart
            # https://rest.arbeitsagentur.de/infosysbub/entgeltatlas/pc/v1/regionen
            occupation_class = call[0]
            level = call[1]
            region = call[2]
            gender = call[3]
            age = call[4]
            branch = call[5]

            params_dict = {
                "l": level,
                "g": gender,
                "a": age,
                "b": branch,
                "r": region,
            }

            # Generate an auth token from the API for further GET requests
            auth_url = 'https://rest.arbeitsagentur.de/oauth/gettoken_cc'
            auth_data = {
                'client_id': 'c4f0d292-9d0f-4763-87dd-d3f9e78fb006',
                'client_secret': '566c4dd6-942f-4cda-aad6-8d611c577107',
                'grant_type': 'client_credentials',
            }
            auth_response = requests.post(auth_url, data=auth_data)

            access_token = auth_response.json()["access_token"]

            request_headers = {'Authorization': f'Bearer {access_token}'}

            logger.log_text(
                f"Will call API for kldb-key {occupation_class} with params " + str(params_dict),
                severity="INFO"
            )

            response = requests.get(
                f"https://rest.arbeitsagentur.de/infosysbub/entgeltatlas/pc/v1/entgelte/{occupation_class}?l={level}&r={region}&a={age}&b={branch}&g={gender}",
                headers=request_headers
            )

            api_result = response.json()

            logger.log_text(
                f"Received api response {api_result}",
                severity="INFO"
            )

            # Since we are passing all arguments to the API call we're expecting an array of 1 element or nothing at all
            # replies array must be the same len as the calls array. Thus, we add an empty element if needed to the output
            if len(api_result) == 0:
                replies.append({})
            if len(api_result) == 1:
                replies.append(api_result[0])
            else:
                return jsonify({"errorMessage": f"Underlying API returned {len(api_result)} elements; expected only one."}), 400

        return_json = jsonify({"replies": replies})
        logger.log_text(
            f"Function call ending. Replies {replies}",
            severity="INFO"
        )
        return return_json

    except Exception as e:
        return jsonify({"errorMessage": str(e)}), 400
