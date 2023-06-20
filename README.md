# Detective control using Cloud Batch

The steps decribed below refered to an article posted in Medium showing how to implement periodical detective control in few command using Cloud Batch, Cloud Scheduler and CFT Scorecard.

## Setting up detective control in GCP

1. Set  environment variables
```
export PROJECT_ID=<PROJECT_ID_TO_REPLACE>                       # Project where all the service are enabled
export CAI_BUCKET=<CAI_BUCKET_TO_REPLACE>                       # GCS bucket used for export and report

export SCAN_ORGANIZATION_ID=<ORGANIZATION_ID_TO_REPLACE>        # Optional, needed if scan on organization needed
export SCAN_FOLDER_ID=<FOLDER_ID_TO_REPLACE>                    # Optional, needed if scan on a specific folder needed
export SCAN_PROJECT_ID=<PROJECT_ID_TO_REPLACE>                  # Optional, needed if scan on a specific project needed
```

2. Set your project and retrieve the project number
```
gcloud config set project $PROJECT_ID  
export PROJECT_NUMBER=`gcloud projects describe $PROJECT_ID \
    --format='value(projectNumber)'`
```

3. Activate the Google APIs on your project
```
gcloud services enable cloudasset.googleapis.com batch.googleapis.com logging.googleapis.com storage.googleapis.com compute.googleapis.com iam.googleapis.com
gcloud beta services identity create --service=cloudasset.googleapis.com
```

4. Assign permission to service account used by Cloud Intentory so export CAI can be stored in a bucket
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --role roles/storage.admin \
    --member \
    serviceAccount:service-$PROJECT_NUMBER@gcp-sa-cloudasset.iam.gserviceaccount.com
```

4. Create a GCS bucket to store CAI export:
```
gcloud storage buckets create gs://$CAI_BUCKET
```

5. Create the service account that will be used to run the Cloud Batch job
```
BATCH_DETECTIVE_SA=batch-detective-sa

gcloud iam service-accounts create ${BATCH_DETECTIVE_SA} \
    --description="Service Account used by Detective Cloud Batch Job"
```

6. Assign the good permissions to the Cloud Batch Job
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --role roles/batch.agentReporter \
    --member \
    serviceAccount:$BATCH_DETECTIVE_SA@$PROJECT_ID.iam.gserviceaccount.com

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --role roles/logging.logWriter \
    --member \
    serviceAccount:$BATCH_DETECTIVE_SA@$PROJECT_ID.iam.gserviceaccount.com 

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --role roles/storage.admin \
    --member \
    serviceAccount:$BATCH_DETECTIVE_SA@$PROJECT_ID.iam.gserviceaccount.com 
```

7. Assign the permissions to perform Cloud Asset export

**For an organization**
```
gcloud organizations add-iam-policy-binding $SCAN_ORGANIZATION_ID \
    --role roles/cloudasset.viewer \
    --member \
    serviceAccount:$BATCH_DETECTIVE_SA@$PROJECT_ID.iam.gserviceaccount.com 
```

**For a folder**
```
gcloud resource-manager folders add-iam-policy-binding $SCAN_FOLDER_ID \
    --role roles/cloudasset.viewer \
    --member \
    serviceAccount:$BATCH_DETECTIVE_SA@$PROJECT_ID.iam.gserviceaccount.com 
```

**For a project**
```
gcloud projects add-iam-policy-binding $SCAN_PROJECT_ID \
    --role roles/cloudasset.viewer \
    --member \
    serviceAccount:$BATCH_DETECTIVE_SA@$PROJECT_ID.iam.gserviceaccount.com 
```

7. Create a Cloud Batch

**For an organization**
```
cd templates
sed -r 's/<SCAN_ORGANIZATION_ID_TO_REPLACE>/'"$SCAN_ORGANIZATION_ID"'/g' batch-organization-orig.json | sed -r 's/<PROJECT_ID_TO_REPLACE>/'"$PROJECT_ID"'/g'  | sed -r 's/<CAI_BUCKET_TO_REPLACE>/'"$CAI_BUCKET"'/g' > batch-organization.json

gcloud batch jobs submit detective-job-orga \
    --location asia-southeast1 \
    --config batch-organization.json
```

**For a folder**
```
cd templates
sed -r 's/<SCAN_FOLDER_ID_TO_REPLACE>/'"$SCAN_FOLDER_ID"'/g' batch-folder-orig.json | sed -r 's/<PROJECT_ID_TO_REPLACE>/'"$PROJECT_ID"'/g' | sed -r 's/<CAI_BUCKET_TO_REPLACE>/'"$CAI_BUCKET"'/g' > batch-folder.json

gcloud batch jobs submit detective-job-folder \
    --location asia-southeast1 \
    --config batch-folder.json
```

**For a project**
```
cd templates
sed -r 's/<SCAN_PROJECT_ID_TO_REPLACE>/'"$SCAN_PROJECT_ID"'/g' batch-project-orig.json  | sed -r 's/<PROJECT_ID_TO_REPLACE>/'"$PROJECT_ID"'/g' | sed -r 's/<CAI_BUCKET_TO_REPLACE>/'"$CAI_BUCKET"'/g' > batch-project.json

gcloud batch jobs submit detective-job-project \
    --location asia-southeast1 \
    --config batch-project.json
```

8. Schedule periodically the checks using Cloud Scheduler
The command below is creating of Cloud Schedule cron to perform detective control on the full organization. You will need to adapt if the scope is for a folder or a project.

```
REGION=asia-southeast1
SCHEDULER_SA=scheduler-detective-sa

gcloud iam service-accounts create ${SCHEDULER_SA} \
    --description="Service Account used by Detective Cloud Scheduler"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --role roles/batch.jobsEditor \
    --member \
    serviceAccount:$SCHEDULER_SA@$PROJECT_ID.iam.gserviceaccount.com

gcloud iam service-accounts add-iam-policy-binding $BATCH_DETECTIVE_SA@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/iam.serviceAccountUser \
    --member \
    serviceAccount:$SCHEDULER_SA@$PROJECT_ID.iam.gserviceaccount.com

gcloud services enable cloudscheduler.googleapis.com

gcloud scheduler jobs create http detective-job --schedule="0 */3 * * *" \
    --uri="https://batch.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/$REGION/jobs" \
    --http-method=POST \
    --location=$REGION \
    --headers=User-Agent=Google-Cloud-Scheduler,Content-Type=application/json \
    --oauth-service-account-email=$SCHEDULER_SA@$PROJECT_ID.iam.gserviceaccount.com \
    --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" \
    --message-body-from-file=batch-organization.json
```


## How to validate script execution

1. Execute detect.sh to find violation of a specific project. This command can be used to ensure that the script is working as expected
```
cd scripts
chmod +x ./detect*.sh 
./detect-project.sh 
```

2. Command below can be used to replace newline by '\n' character and copy it in the template file
```
< detect-project.sh sed '$!G' | paste -sd '\\n' -
```