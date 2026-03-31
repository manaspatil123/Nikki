Pricing for PDF/TIFF document text detection is at the `DOCUMENT_TEXT_DETECTION` or `TEXT_DETECTION` rate. Please see the [Pricing](https://cloud.google.com/vision/pricing?_gl=1*tmt07k*_ga*ODc5NDU3MzAzLjE3NTk5NjY0NzA.*_ga_WH2QY8WWF5*czE3NzQ0NDY5NTUkbzMkZzEkdDE3NzQ0NDk4MDMkajM2JGwwJGgw) page for details.Currently `DOCUMENT_TEXT_DETECTION` and `TEXT_DETECTION` are the only [feature types](https://docs.cloud.google.com/vision/docs/features-list) available for offline (asynchronous) large batch file (PDF/TIFF) annotation.

The Vision API can detect and transcribe text from PDF and TIFF files stored in Cloud Storage.

Document text detection from PDF and TIFF must be requested using the `files:asyncBatchAnnotate` function, which performs an offline (asynchronous) request and provides its status using the `operations` resources.

Output from a PDF/TIFF request is written to a JSON file created in the specified Cloud Storage bucket.

## Limitations

The Vision API accepts PDF/TIFF files up to 2000 pages. Larger files will return an error.

## Authentication

API keys are not supported for `files:asyncBatchAnnotate` requests. See [Using a service account](https://docs.cloud.google.com/vision/docs/auth#using_a_service_account) for instructions on authenticating with a service account.

The account used for authentication must have access to the Cloud Storage bucket that you specify for the output (`roles/editor` or `roles/storage.objectCreator` or above).

You **can** use an API key to query the status of the operation; see [Using an API key](https://docs.cloud.google.com/vision/docs/auth#using_an_api_key) for instructions.

## Document text detection requests

Currently PDF/TIFF document detection is only available for files stored in Cloud Storage buckets. Response JSON files are similarly saved to a Cloud Storage bucket.

![2010 US census PDF page](https://docs.cloud.google.com/static/vision/docs/images/census2010.jpg)`gs://cloud-samples-data/vision/pdf_tiff/census2010.pdf`, ***Source\***: [United States Census Bureau](https://www.census.gov/data.html).



**Note:** This feature returns results with `normalizedVertices` [0,1] and not real pixel values (`vertices`).



[REST](https://docs.cloud.google.com/vision/docs/pdf#rest)[Go](https://docs.cloud.google.com/vision/docs/pdf#go)[Java](https://docs.cloud.google.com/vision/docs/pdf#java)[Node.js](https://docs.cloud.google.com/vision/docs/pdf#node.js)[Python](https://docs.cloud.google.com/vision/docs/pdf#python)[gcloud](https://docs.cloud.google.com/vision/docs/pdf#gcloud)[Additional languages](https://docs.cloud.google.com/vision/docs/pdf#additional-languages)

Before using any of the request data, make the following replacements:

- CLOUD_STORAGE_BUCKET: A Cloud Storage bucket/directory to save output files to, expressed in the following form:

  - `gs://bucket/directory/`

  The requesting user must have write permission to the bucket.

- CLOUD_STORAGE_FILE_URI: the path to a valid file (PDF/TIFF) in a Cloud Storage bucket. You must at least have read privileges to the file. Example:

  - 

    ```
    gs://cloud-samples-data/vision/pdf_tiff/census2010.pdf
    ```

- FEATURE_TYPE: A valid feature type. For `files:asyncBatchAnnotate` requests you can use the following feature types:

  - `DOCUMENT_TEXT_DETECTION`
  - `TEXT_DETECTION`

- PROJECT_ID: Your Google Cloud project ID.

**Field-specific considerations:**

- `inputConfig` - replaces the `image` field used in other Vision API requests. It contains two child fields:

  - `gcsSource.uri` - the Google Cloud Storage URI of the PDF or TIFF file (accessible to the user or service account making the request).
  - `mimeType` - one of the accepted file types: `application/pdf` or `image/tiff`.

- `outputConfig` - specifies output details. It contains two child field:

  - `gcsDestination.uri` - a valid Google Cloud Storage URI. The bucket must be writeable by the user or service account making the request. The filename will be `output-x-to-y`, where `x` and `y` represent the PDF/TIFF page numbers included in that output file. If the file exists, its contents will be overwritten.

  - `batchSize` - specifies how many pages of output should be included in each output JSON file.

  - HTTP method and URL:

    ```
    POST https://vision.googleapis.com/v1/files:asyncBatchAnnotate
    ```

    Request JSON body:

    ```
    {
      "requests":[
        {
          "inputConfig": {
            "gcsSource": {
              "uri": "CLOUD_STORAGE_FILE_URI"
            },
            "mimeType": "application/pdf"
          },
          "features": [
            {
              "type": "FEATURE_TYPE"
            }
          ],
          "outputConfig": {
            "gcsDestination": {
              "uri": "CLOUD_STORAGE_BUCKET"
            },
            "batchSize": 1
          }
        }
      ]
    }
    ```

    To send your request, choose one of these options:

    [curl](https://docs.cloud.google.com/vision/docs/pdf#curl)[PowerShell](https://docs.cloud.google.com/vision/docs/pdf#powershell)

    **Note:** The following command assumes that you have logged in to the `gcloud` CLI with your user account by running [`gcloud init`](https://docs.cloud.google.com/sdk/gcloud/reference/init) or [`gcloud auth login`](https://docs.cloud.google.com/sdk/gcloud/reference/auth/login) , or by using [Cloud Shell](https://docs.cloud.google.com/shell/docs), which automatically logs you into the `gcloud` CLI . You can check the currently active account by running [`gcloud auth list`](https://docs.cloud.google.com/sdk/gcloud/reference/auth/list).

    Save the request body in a file named `request.json`, and execute the following command:

    ```
    curl -X POST \
         -H "Authorization: Bearer $(gcloud auth print-access-token)" \
         -H "x-goog-user-project: PROJECT_ID" \
         -H "Content-Type: application/json; charset=utf-8" \
         -d @request.json \
         "https://vision.googleapis.com/v1/files:asyncBatchAnnotate"
    ```

    **Response:**

    A successful `asyncBatchAnnotate` request returns a response with a single name field:

    ```
    {
      "name": "projects/usable-auth-library/operations/1efec2285bd442df"
    }
    ```

    This name represents a long-running operation with an associated ID (for example, `1efec2285bd442df`), which can be queried using the `v1.operations` API.

    To retrieve your Vision annotation response, send a GET request to the `v1.operations` endpoint, passing the operation ID in the URL:

    ```
    GET https://vision.googleapis.com/v1/operations/operation-id
    ```

    For example:

    ```
    curl -X GET -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
    -H "Content-Type: application/json" \
    https://vision.googleapis.com/v1/projects/project-id/locations/location-id/operations/1efec2285bd442df
    ```

    If the operation is in progress:

    ```
    {
      "name": "operations/1efec2285bd442df",
      "metadata": {
        "@type": "type.googleapis.com/google.cloud.vision.v1.OperationMetadata",
        "state": "RUNNING",
        "createTime": "2019-05-15T21:10:08.401917049Z",
        "updateTime": "2019-05-15T21:10:33.700763554Z"
      }
    }
    ```

    Once the operation has completed, the `state` shows as `DONE` and your results are written to the Google Cloud Storage file you specified:

    ```
    {
      "name": "operations/1efec2285bd442df",
      "metadata": {
        "@type": "type.googleapis.com/google.cloud.vision.v1.OperationMetadata",
        "state": "DONE",
        "createTime": "2019-05-15T20:56:30.622473785Z",
        "updateTime": "2019-05-15T20:56:41.666379749Z"
      },
      "done": true,
      "response": {
        "@type": "type.googleapis.com/google.cloud.vision.v1.AsyncBatchAnnotateFilesResponse",
        "responses": [
          {
            "outputConfig": {
              "gcsDestination": {
                "uri": "gs://your-bucket-name/folder/"
              },
              "batchSize": 1
            }
          }
        ]
      }
    }
    ```

    The JSON in your output file is similar to that of an image's [document text detection request](/vision/docs/ocr), with the addition of a `context` field showing the location of the PDF or TIFF that was specified and the number of pages in the file:

    ```
    output-1-to-1.json
    ```

     **Full file**

    

    ## Multi-regional support

    This functionality currently only applies to the OCR feature (types `TEXT_DETECTION` or `DOCUMENT_TEXT_DETECTION`).

    You can now specify continent-level data storage and OCR processing. The following regions are currently supported:

    - `us`: USA country only
    - `eu`: The European Union

    ### Locations

    Cloud Vision offers you some control over where the resources for your project are stored and processed. In particular, you can configure Cloud Vision to store and process your data only in the European Union.

    By default Cloud Vision stores and processes resources in a **Global** location, which means that Cloud Vision doesn't guarantee that your resources will remain within a particular location or region. If you choose the **European Union** location, Google will store your data and process it only in the European Union. You and your users can access the data from any location.

    ### Setting the location using the API

    The Vision API supports a global API endpoint (`vision.googleapis.com`) and also two region-based endpoints: a European Union endpoint (`eu-vision.googleapis.com`) and United States endpoint (`us-vision.googleapis.com`). Use these endpoints for region-specific processing. For example, to store and process your data in the European Union only, use the URI `eu-vision.googleapis.com` in place of `vision.googleapis.com` for your REST API calls:

    - https://**eu-**vision.googleapis.com/v1/projects/PROJECT_ID/locations/**eu**/images:annotate
    - https://**eu-**vision.googleapis.com/v1/projects/PROJECT_ID/locations/**eu**/images:asyncBatchAnnotate
    - https://**eu-**vision.googleapis.com/v1/projects/PROJECT_ID/locations/**eu**/files:annotate
    - https://**eu-**vision.googleapis.com/v1/projects/PROJECT_ID/locations/**eu**/files:asyncBatchAnnotate

    To store and process your data in the United States only, use the US endpoint (`us-vision.googleapis.com`) with the preceding methods.

    ### Setting the location using the client libraries

    The Vision API client libraries accesses the global API endpoint (`vision.googleapis.com`) by default. To store and process your data in the European Union only, you need to explicitly set the endpoint (`eu-vision.googleapis.com`). The following code samples show how to configure this setting.

    

    **Note:** This feature returns results with `normalizedVertices` [0,1] and not real pixel values (`vertices`).

    

    [REST](https://docs.cloud.google.com/vision/docs/pdf#rest)[Go](https://docs.cloud.google.com/vision/docs/pdf#go)[Java](https://docs.cloud.google.com/vision/docs/pdf#java)[Node.js](https://docs.cloud.google.com/vision/docs/pdf#node.js)[Python](https://docs.cloud.google.com/vision/docs/pdf#python)

    Before using any of the request data, make the following replacements:

    - REGION_ID: One of the valid regional location identifiers:

      - `us`: USA country only
      - `eu`: The European Union

    - CLOUD_STORAGE_IMAGE_URI: the path to a valid image file in a Cloud Storage bucket. You must at least have read privileges to the file. Example:

      - 

        ```
        gs://cloud-samples-data/vision/pdf_tiff/census2010.pdf
        ```

    - CLOUD_STORAGE_BUCKET: A Cloud Storage bucket/directory to save output files to, expressed in the following form:

      - `gs://bucket/directory/`

      The requesting user must have write permission to the bucket.

    - FEATURE_TYPE: A valid feature type. For `files:asyncBatchAnnotate` requests you can use the following feature types:

      - `DOCUMENT_TEXT_DETECTION`
      - `TEXT_DETECTION`

    - PROJECT_ID: Your Google Cloud project ID.

    **Field-specific considerations:**

    - `inputConfig` - replaces the `image` field used in other Vision API requests. It contains two child fields:
      - `gcsSource.uri` - the Google Cloud Storage URI of the PDF or TIFF file (accessible to the user or service account making the request).
      - `mimeType` - one of the accepted file types: `application/pdf` or `image/tiff`.
    - `outputConfig` - specifies output details. It contains two child field:
      - `gcsDestination.uri` - a valid Google Cloud Storage URI. The bucket must be writeable by the user or service account making the request. The filename will be `output-x-to-y`, where `x` and `y` represent the PDF/TIFF page numbers included in that output file. If the file exists, its contents will be overwritten.
      - `batchSize` - specifies how many pages of output should be included in each output JSON file.

    HTTP method and URL:

    ```
    POST https://REGION_ID-vision.googleapis.com/v1/projects/PROJECT_ID/locations/REGION_ID/files:asyncBatchAnnotate
    ```

    Request JSON body:

    ```
    {
      "requests":[
        {
          "inputConfig": {
            "gcsSource": {
              "uri": "CLOUD_STORAGE_IMAGE_URI"
            },
            "mimeType": "application/pdf"
          },
          "features": [
            {
              "type": "FEATURE_TYPE"
            }
          ],
          "outputConfig": {
            "gcsDestination": {
              "uri": "CLOUD_STORAGE_BUCKET"
            },
            "batchSize": 1
          }
        }
      ]
    }
    ```

    To send your request, choose one of these options:

    [curl](https://docs.cloud.google.com/vision/docs/pdf#curl)[PowerShell](https://docs.cloud.google.com/vision/docs/pdf#powershell)

    **Note:** The following command assumes that you have logged in to the `gcloud` CLI with your user account by running [`gcloud init`](https://docs.cloud.google.com/sdk/gcloud/reference/init) or [`gcloud auth login`](https://docs.cloud.google.com/sdk/gcloud/reference/auth/login) , or by using [Cloud Shell](https://docs.cloud.google.com/shell/docs), which automatically logs you into the `gcloud` CLI . You can check the currently active account by running [`gcloud auth list`](https://docs.cloud.google.com/sdk/gcloud/reference/auth/list).

    Save the request body in a file named `request.json`, and execute the following command:

    ```
    curl -X POST \
         -H "Authorization: Bearer $(gcloud auth print-access-token)" \
         -H "x-goog-user-project: PROJECT_ID" \
         -H "Content-Type: application/json; charset=utf-8" \
         -d @request.json \
         "https://REGION_ID-vision.googleapis.com/v1/projects/PROJECT_ID/locations/REGION_ID/files:asyncBatchAnnotate"
    ```

    **Response:**

    A successful `asyncBatchAnnotate` request returns a response with a single name field:

    ```
    {
      "name": "projects/usable-auth-library/operations/1efec2285bd442df"
    }
    ```

    This name represents a long-running operation with an associated ID (for example, `1efec2285bd442df`), which can be queried using the `v1.operations` API.

    To retrieve your Vision annotation response, send a GET request to the `v1.operations` endpoint, passing the operation ID in the URL:

    ```
    GET https://vision.googleapis.com/v1/operations/operation-id
    ```

    For example:

    ```
    curl -X GET -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
    -H "Content-Type: application/json" \
    https://vision.googleapis.com/v1/projects/project-id/locations/location-id/operations/1efec2285bd442df
    ```

    If the operation is in progress:

    ```
    {
      "name": "operations/1efec2285bd442df",
      "metadata": {
        "@type": "type.googleapis.com/google.cloud.vision.v1.OperationMetadata",
        "state": "RUNNING",
        "createTime": "2019-05-15T21:10:08.401917049Z",
        "updateTime": "2019-05-15T21:10:33.700763554Z"
      }
    }
    ```

    Once the operation has completed, the `state` shows as `DONE` and your results are written to the Google Cloud Storage file you specified:

    ```
    {
      "name": "operations/1efec2285bd442df",
      "metadata": {
        "@type": "type.googleapis.com/google.cloud.vision.v1.OperationMetadata",
        "state": "DONE",
        "createTime": "2019-05-15T20:56:30.622473785Z",
        "updateTime": "2019-05-15T20:56:41.666379749Z"
      },
      "done": true,
      "response": {
        "@type": "type.googleapis.com/google.cloud.vision.v1.AsyncBatchAnnotateFilesResponse",
        "responses": [
          {
            "outputConfig": {
              "gcsDestination": {
                "uri": "gs://your-bucket-name/folder/"
              },
              "batchSize": 1
            }
          }
        ]
      }
    }
    ```

    The JSON in your output file is similar to that of an image's [document text detection](https://docs.cloud.google.com/vision/docs/handwriting#detect_document_text_in_a_remote_image) response if you used the `DOCUMENT_TEXT_DETECTION` feature, or [text detection](https://docs.cloud.google.com/vision/docs/ocr#detect_text_in_a_remote_image) response if you used the `TEXT_DETECTION` feature. The output will have an additional `context` field showing the location of the PDF or TIFF that was specified and the number of pages in the file:

    ```
    output-1-to-1.json
    ```

     **Full file**

    **Note: Zero coordinate values omitted.** When the API detects a coordinate ("x" or "y") value of 0, ***that coordinate is omitted in the JSON response\***. Thus, a response with a bounding poly around the entire image would be
    **[{},{"x": 1},{"x": 1,"y": 1},{"y": 1}]**. For more information, see the [API Reference documentation](https://cloud.google.com/vision/docs/reference/rest/v1/images/annotate#boundingpoly).

    1. 

    2. ```
           {
         "inputConfig": {
           "gcsSource": {
             "uri": "gs://cloud-samples-data/vision/pdf_tiff/census2010.pdf"
           },
           "mimeType": "application/pdf"
         },
         "responses": [
           {
             "fullTextAnnotation": {
               "pages": [
                 {
                   "property": {
                     "detectedLanguages": [
                       {
                         "languageCode": "en",
                         "confidence": 0.94
                       }
                     ]
                   },
                   "width": 612,
                   "height": 792,
                   "blocks": [
                     {
                       "boundingBox": {
                         "normalizedVertices": [
                           {
                             "x": 0.12908497,
                             "y": 0.10479798
                           },
                           ...
                           {
                             "x": 0.12908497,
                             "y": 0.1199495
                           }
                         ]
                       },
                       "paragraphs": [
                         {
                         ...
                           },
                           "words": [
                             {
                               ...
                               },
                               "symbols": [
                                 {
                                 ...
                                   "text": "C",
                                   "confidence": 0.99
                                 },
                                 {
                                   "property": {
                                     "detectedLanguages": [
                                       {
                                         "languageCode": "en"
                                       }
                                     ]
                                   },
                                   "text": "O",
                                   "confidence": 0.99
                                 },
                    ...
                    }
                   ]
                 }
               ],
               "text": "CONTENTS\n.\n1-1\nII-1\nIII-1\nList of Statistical Tables...
               \nHow to Use This Census Report ..\nTable Finding Guide .\nUser
               Notes .......\nStatistical Tables.........\nAppendixes
               \nA Geographic Terms and Concepts .........\nB Definitions of
               Subject Characteristics.\nData Collection and Processing Procedures...
               \nQuestionnaire. ........\nE Maps .................\nF Operational
               Overview and accuracy of the Data.......\nG Residence Rule and
               Residence Situations for the \n2010 Census of the United States...
               \nH Acknowledgments .....\nE\n*Appendix may be found in the separate
               volume, CPH-1-A, Summary Population and\nHousing Characteristics,
               Selected Appendixes, on the Internet at
               <www.census.gov\n/prod/cen2010/cph-1-a.pdf>.\nContents\n"
             },
             "context": {
               "uri": "gs://cloud-samples-data/vision/pdf_tiff/census2010.pdf",
               "pageNumber": 1
             }
           }
         ]
       }
          
       ```