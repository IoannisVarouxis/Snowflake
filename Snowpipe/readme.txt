
Local - Prepare openSsl
d:\Tools\OpenSSL>start.bat

Create public - provate key pairs
    https://docs.snowflake.com/en/user-guide/key-pair-auth


Step 1: Generate the Private Key
    openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt


Step 2: Generate a Public Key
    openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
    
Step 4: Assign the Public Key to a Snowflake User
    CREATE USER SNOWPIPE_USER PASSWORD='<user_pwd>' DEFAULT_ROLE = DEPLOYMENT_DB_PRD DEFAULT_SECONDARY_ROLES = ('ALL') MUST_CHANGE_PASSWORD = FALSE;
    ALTER USER SNOWPIPE_USER SET RSA_PUBLIC_KEY='<public_key - rsa_key.pub>';


Python - env
cd Miniconda3\condabin
activate.bat

Create JWT Token
python D:\Projects\Snowflake\Snowpipe\sql-api-generate-jwt.py --account <acount_name> --user SNOWPIPE_USER --private_key_file_path D:\Projects\Snowflake\Snowpipe\rsa_key.p8


Call REST API - insertFiles
python D:\Projects\Snowflake\Snowpipe\call-insertFiles.py
