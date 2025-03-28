# provider-upjet-alibabacloud

## Build

Run the following to build the provider locally.

```
make submodules
make generate
```

## Test

Add an environment variable to set the credentials for the target Alibaba
account for the tests as follows and then run `make e2e`.

```
export UPTEST_CLOUD_CREDENTIALS='{
    "access_key": "...",
    "secret_key": "...",
    "region": "us-west-1"
}'
```
