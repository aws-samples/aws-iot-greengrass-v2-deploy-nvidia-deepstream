import os
import numpy as np
import dlr
import argparse
import platform
import cv2
import time
import datetime
import time
from datetime import datetime
import logging
import json
import IPCUtils as ipcutil
from labels import labels
from awscrt.io import (
    ClientBootstrap,
    DefaultHostResolver,
    EventLoopGroup,
    SocketDomain,
    SocketOptions,
)
from awsiot.eventstreamrpc import Connection, LifecycleHandler, MessageAmendment
from awsiot.greengrasscoreipc.model import PublishToIoTCoreRequest
import awsiot.greengrasscoreipc.client as client

os.system("echo {}".format("Using dlr from '{}'.".format(dlr.__file__)))
os.system("echo {}".format("Using numpy from '{}'.".format(np.__file__)))
os.system("echo {}".format("Using cv2 from '{}'.".format(cv2.__file__)))
hostname = os.getenv("AWS_GG_NUCLEUS_DOMAIN_SOCKET_FILEPATH_FOR_COMPONENT")
print("hostname=", hostname)
print("svcid=", os.getenv("SVCUID"))
enableSendMessages = True
# if "SVCUID" in os.environ and "AWS_GG_NUCLEUS_DOMAIN_SOCKET_FILEPATH_FOR_COMPONENT" in os.environ:
#     print("Found SVUID and AWS_GG_NUCLEUS_DOMAIN_SOCKET_FILEPATH_FOR_COMPONENT enable messaging.")
#     enableSendMessages = True

TIMEOUT = 10
if enableSendMessages:
   ipc_utils = ipcutil.IPCUtils()
   connection = ipc_utils.connect()
   ipc_client = client.GreengrassCoreIPCClient(connection)


def enable_camera():
    global camera
    if platform.machine() == "armv7l":  # RaspBerry Pi
        import picamera
        camera = picamera.PiCamera()
    elif platform.machine() == "aarch64":  # Nvidia Jetson TX
        camera = cv2.VideoCapture("nvarguscamerasrc ! video/x-raw(memory:NVMM)," +
                                  "width=(int)1920, height=(int)1080, format=(string)NV12," +
                                  "framerate=(fraction)30/1 ! nvvidconv flip-method=2 !" +
                                  "video/x-raw, width=(int)1920, height=(int)1080," +
                                  "format=(string)BGRx ! videoconvert ! appsink")
    elif platform.machine() == "x86_64":  # Deeplens
        import awscam
        camera = awscam


def predict(image_data):
    r"""
    Predict image with DLR.
    :param image: numpy array of the Image inference with.
    """
    try:
        # Run DLR to perform inference with DLC optimized model
        model_output = dlr_model.run(image_data)
        max_score_id = np.argmax(model_output)
        max_score = np.max(model_output)
        print("max score id:",max_score_id)
        print("class:",labels[max_score_id])
        print("max score",str(max_score))
        probabilities = model_output[0][0]
        sort_classes_by_probability = np.argsort(probabilities)[::-1]
        results_file = "{}/{}.log".format(results_directory,os.path.basename(os.path.realpath(model_path)))
        message = '{"class":"' + labels[max_score_id] + '"' + ',"confidence":"' + str(max_score) +'"}'
        payload = {
            "message": message,
            "timestamp": datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
        }
        topic = "demo/topic"
        if enableSendMessages:
           ipc_client.new_publish_to_iot_core().activate(
               request=PublishToIoTCoreRequest(topic_name=topic, qos='0',
                                            payload=json.dumps(payload).encode()))

        with open(results_file, 'a') as f:
            print("{}: Top {} predictions with score {} or above ".format(str(
                datetime.now()), max_no_of_results, score_threshold), file=f)
            for i in sort_classes_by_probability[:max_no_of_results]:
                if probabilities[i] >= score_threshold:
                    print("[ Class: {}, Score: {} ]".format(
                        labels[i], probabilities[i]), file=f)

    except Exception as e:
        print("Exception occurred during prediction: %s", e)


def predict_from_image(image):
    r"""
    reshape the captured image and predict using it.
    """
    #cvimage = cv2.resize(image, reshape)
    predict(image)


def send_mqtt_message(message):
    request = PublishToIotCoreRequest()
    request.topic_name = "neo-detect"
    request.payload = bytes(message, "utf-8")
    request.qos = QOS.AT_LEAST_ONCE
    operation = ipc_client.new_publish_to_iot_core()
    operation.activate(request)
    future = operation.get_response()
    future.result(TIMEOUT)


def predict_from_cam():
    if camera is None:
        print("Unable to support camera")
        return
    if platform.machine() == "armv7l":  # RaspBerry Pi
        stream = io.BytesIO()
        camera.start_preview()
        time.sleep(2)
        camera.capture(stream, format='jpeg')
        # Construct a numpy array from the stream
        data = np.fromstring(stream.getvalue(), dtype=np.uint8)
        # "Decode" the image from the array, preserving colour
        cvimage = cv2.imdecode(data, 1)
    elif platform.machine() == "aarch64":  # Nvidia Jetson TX
        if camera.isOpened():
            ret, cvimage = camera.read()
            cv2.destroyAllWindows()
        else:
            raise RuntimeError("Cannot open the camera")
    elif platform.machine() == "x86_64":  # Deeplens
        ret, cvimage = camera.getLastFrame()
        if ret == False:
            raise RuntimeError("Failed to get frame from the stream")
    return predict_from_image(cvimage)



# Passed arguments
parser = argparse.ArgumentParser()
parser.add_argument("--accelerator",
                    "-a",
                    default="gpu",
                    help="gpu/cpu/opencl")
parser.add_argument("--modelPath",
                    "-m",
                    help="path to model")
parser.add_argument("--mlRootPath",
                    "-p",
                    help="path to inference result and images")
parser.add_argument("--imageName",
                    "-i",
                    help="image name")
parser.add_argument("--interval",
                    "-s", default=60,
                    help="prediction interval in seconds")

args = parser.parse_args()

model_path = args.modelPath
context = args.accelerator
mlRootPath = args.mlRootPath
imageName = args.imageName
prediction_interval_secs = args.interval
reshape = (224, 224)
score_threshold = 0.3
max_no_of_results = 5
camera = None
image_data = None
sample_image = (mlRootPath + "/images/" + imageName).format(
    os.path.dirname(os.path.realpath(__file__)))
results_directory = mlRootPath + "/inference_log/"
# Create the results directory if it does not exist already
os.makedirs(results_directory, exist_ok=True)

# Initialize example Resnet model
dlr_model = dlr.DLRModel(model_path, context)

os.system("echo {}".format("Inference logs can be found under the directory '{}' in the name of the model used. ".format(
    results_directory)))

# Load image based on the format - support jpg,jpeg,png and npy.

def load_image(img):
    if img.endswith(".jpg", -4,) or img.endswith(".png", -4,) or img.endswith(".jpeg", -5,):
        image = bytearray(open(img, 'rb').read())
        image_data = cv2.imdecode(np.frombuffer(image, dtype=np.uint8), cv2.IMREAD_UNCHANGED)
        image_data = cv2.resize(image_data, (224,224))
        print("loaded image:",imageName)
    elif img.endswith(".npy", -4,):
        # the shape for the resnet18 model is [1,3,224,224]
        image_data = np.load(img).astype(np.float32)

    return image_data


# enable_camera()

while True:
    # predict_from_cam()
    
    image_data = load_image(sample_image)
    if image_data is not None:
        predict_from_image(image_data)
    else:
        os.system("Images of format jpg,jpeg,png and npy are only supported.")
    image_data = None
    time.sleep(int(prediction_interval_secs))
