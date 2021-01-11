## Using Image Inference and Video Analytics Pipelines with Greengrass V2 and NVIDIA Jetson

This repository will give you concrete examples to get starting using GreengrassV2 to build Image Inferencing and Video Analytics Pipelines


Technologies used:

* GreengrassV2
* NVIDIA Deepstream 5.0
* Sagemaker NEO DLR


## Prerequisites

* GreengrassV2 (https://docs.aws.amazon.com/greengrass/v2/developerguide/getting-started.html)
* AWS CLI with GreengrassV2 support (https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) 
* Jetpack 4.4 (https://developer.nvidia.com/EMBEDDED/Jetpack)
* numpy (This takes a long time to install, if you don't have it installer will try to install)
* opencv-python (Should be pre-installed with Jetpack 4.4)


## Image Inference
*PLEASE NOTE*: This deployment may install/modify components on your Jetson device. It will install some python packages outside of a virtual environment. This is because python-opencv is specially installed as part of Jetpack 4.4 and the debian package may run for a long period of time and not succesfully complete (numpy can also take a long time to install).

replace GreengrassCore where mentioned 
run:
```
 cd ~/GreengrassCore
 aws greengrassv2 create-component-version --inline-recipe fileb://recipes/aws.greengrass.JetsonDLRImageClassification-1.0.0.json
 aws greengrassv2 create-component-version --inline-recipe fileb://recipes/variant.Jetson.DLR-1.0.0.json
 aws greengrassv2 create-component-version --inline-recipe fileb://recipes/variant.Jetson.ImageClassification.ModelStore-1.0.0.json
```

deploy:
- Go to AWS Iot Core Console (https://console.aws.amazon.com/iot/home)
- Choose Greengrass -> Components
- You should see the components you created via the AWS CLI.
- Choose any one of the three components you created
- Choose 'Deploy'
- Choose 'Create new deployment' then choose 'Next'
- For 'Name' give the deployment a name
- For 'Target type' enter the name of your device core (https://console.aws.amazon.com/iot/home?region=us-east-1#/greengrass/v2/cores)
- Choose 'Next'
- On the 'Select Components' screen, make sure to select all 3 of the components you created and Choose 'Next'
- On the 'Configure Components' screen, choose Next
- On the 'Configure advanced settings' screen, choose Next
- On the 'Review' screen choose 'Deploy'

success:
Now let's go to the MQTT Test client in the AWS Console to see our inference working:
- Inside of IoT Core console, choose 'Test' then 'MQTT Test Client'
- Subscribe to topic 'demo/topic'
- You should see messages looking like the following:
```
{
  "message": "{\"class\":\"Chihuahua\",\"confidence\":\"17.977331\"}",
  "timestamp": "2021-01-06T18:30:05"
}
```



troubleshooting:
- if you get a failure, check the 'greengrass.log' file on your Jetson device in /greengrass/v2/logs/greengrass.log and /greengrass/v2/logs/aws.greengrass.JetsonDLRImageClassification.log

## Deepstream Video Analytica Pipelines



## License

This library is licensed under the MIT-0 License. See the LICENSE file.

