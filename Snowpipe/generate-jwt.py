from datetime import timedelta, timezone, datetime

# This example relies on the PyJWT module (https://pypi.org/project/PyJWT/).
import jwt

# Construct the fully qualified name of the user in uppercase.
# - Replace <account_identifier> with your account identifier.
#   (See https://docs.snowflake.com/en/user-guide/admin-account-identifier.html .)
# - Replace <user_name> with your Snowflake user name.
account = "<account_name>"
user = "<snowpipe_user>"
public_key_fp = "<public_key>"
private_key = ""

# Get the account identifier without the region, cloud provider, or subdomain.
if not '.global' in account:
    idx = account.find('.')
    if idx > 0:
        account = account[0:idx]
    else:
        # Handle the replication case.
        idx = account.find('-')
        if idx > 0:
            account = account[0:idx]

# Use uppercase for the account identifier and user name.
account = account.upper()
user = user.upper()
qualified_username = account + "." + user

# Get the current time in order to specify the time when the JWT was issued and the expiration time of the JWT.
now = datetime.now(timezone.utc)

# Specify the length of time during which the JWT will be valid. You can specify at most 1 hour.
lifetime = timedelta(minutes=59)

# Create the payload for the token.
payload = {

    # Set the issuer to the fully qualified username concatenated with the public key fingerprint (calculated in the  previous step).
    "iss": qualified_username + '.' + public_key_fp,

    # Set the subject to the fully qualified username.
    "sub": qualified_username,

    # Set the issue time to now.
    "iat": now,

    # Set the expiration time, based on the lifetime specified for this object.
    "exp": now + lifetime
}

# Generate the JWT. private_key is the private key that you read from the private key file in the previous step when you generated the public key fingerprint.
encoding_algorithm="RS256"
token = jwt.encode(payload, key=private_key, algorithm=encoding_algorithm)

# If you are using a version of PyJWT prior to 2.0, jwt.encode returns a byte string, rather than a string.
# If the token is a byte string, convert it to a string.
if isinstance(token, bytes):
  token = token.decode('utf-8')
decoded_token = jwt.decode(token, key=private_key.public_key(), algorithms=[encoding_algorithm])
print("Generated a JWT with the following payload:\n{}".format(decoded_token))
