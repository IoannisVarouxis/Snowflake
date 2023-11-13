import requests

jwt_token = "<jwt from generate-jwt.py>" # TODO import generate-jwt.py and use as function
header_bearer = "BEARER " + jwt_token

account = "<acount_name>.west-europe.privatelink"
pipe_name = "DB_DEV.PUBLIC.PIPE_TEST"
request_id = "000-000-001" # create new GUID

headers =  {"Content-Type": "application/json", "Authorization": header_bearer}

data = {
  "files":[
    {
      "path":"filePath/file1.csv",
      "size":100
    },
    {
      "path":"filePath/file2.csv",
      "size":100
    }
  ]
}

api_url = f"https://{account}.snowflakecomputing.com/v1/data/pipes/{pipe_name}/insertFiles?requestId={request_id}"

print('URL: ')
print(api_url)

print('BEARER: ')
print(header_bearer)

print('')

response = requests.post(api_url, json = data, headers = headers)

print('')
print(f"HTTP CODE: {response.status_code} - BODY: {response.content}")
#response.json()
