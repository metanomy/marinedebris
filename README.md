# Tampa Bay Marine Debris App

A cross-platform React Native app for reporting marine debris in the Tamba Bay area.

## Getting started

1. Follow React Native [getting started guide](https://facebook.github.io/react-native/docs/getting-started.html) to set up the development environment.
2. [Generate S3 keys](https://s3.amazonaws.com/doc/s3-example-code/post/post_sample.html) based on the sample policy document below.
3. Copy the `environment.sample.js` as `environment.js` in the project root folder and add the generated keys.
4. Run the app as detailed in the React Native documentation.

## Sample policy document

```json
{
  "expiration": "2100-01-01T12:00:00.000Z",
  "conditions": [
    {"bucket": "YOUR_BUCKET_NAME" },
    {"acl": "private" },
    ["starts-with", "$key", ""],
    ["starts-with", "$Content-Type", ""],
    ["starts-with", "$success_action_status", ""],
  ]
}
```