End to end kserve installation

Det-environments-24586f0


ssh -i "andrew-determined-env.pem" ubuntu@ec2-54-82-63-88.compute-1.amazonaws.com -L 8008:localhost:8008

Install Kind

sudo apt-get update && sudo apt-get install nano screen

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.18.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

kind create cluster

Install kubectl 

Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

Copy and Paste kserve_install.sh
nano kserve_install.sh
bash kserve_install.sh


Patch domain for local connection

kubectl patch cm config-domain --patch '{"data":{"example.com":""}}' -n knative-serving

Create namespace
kubectl create ns kserve-test


Create InferenceService

kubectl apply -n kserve-test -f - <<EOF
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "sklearn-iris"
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      storageUri: "gs://kfserving-examples/models/sklearn/1.0/model"
EOF

Create Test input

cat <<EOF > "./iris-input.json"
{ 
  "instances": [
    [6.8,  2.8,  4.8,  1.4],
    [6.0,  3.4,  4.5,  1.6]
  ]
}
EOF


Jupyterlab

sudo apt-get update && sudo apt-get  install python3.8-venv
python3 -m venv kserve_env python=3.8

source kserve_env/bin/activate
Pip install kserve

jupyter lab --ip=0.0.0.0 --port=8008 --NotebookApp.token='' --NotebookApp.password=''

Create two terminals

Terminal one
INGRESS_GATEWAY_SERVICE=$(kubectl get svc --namespace istio-system --selector="app=istio-ingressgateway" --output jsonpath='{.items[0].metadata.name}')

echo $INGRESS_GATEWAY

Terminal 2
Test kserve 

MODEL_NAME=sklearn-iris
INPUT_PATH=@./iris-input.json
CLUSTER_IP=localhost:8080
 SERVICE_HOSTNAME=$(kubectl get -n kserve-test inferenceservice ${MODEL_NAME} -o jsonpath='{.status.url}' | cut -d "/" -f 3)
curl -v -H "Host: ${SERVICE_HOSTNAME}" -H "Cookie: authservice_session=${SESSION}" http://${CLUSTER_IP}/v1/models/${MODEL_NAME}:predict -d ${INPUT_PATH}


Set up Persistent Volume Claim to run models locally
https://kserve.github.io/website/0.10/modelserving/storage/pvc/pvc/#copy-model-to-pv 
https://kserve.github.io/website/0.10/modelserving/storage/pvc/pvc/#create-pv-and-pvc

Create folder called k8s_pvc_files/ and create file pv-and-pvc.yaml

Paste content: 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/home/ubuntu/mnt/data"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

Run command:
kubectl apply -f k8s_pvc_files/pv-and-pvc.yaml 

Create Pytorch files for local model loading
https://kserve.github.io/website/0.10/modelserving/v1beta1/torchserve/ 
Git clone https://github.com/pytorch/serve.git 

pip install torch-model-archiver

cd serve/examples/image_classifier/
export ENABLE_TORCH_PROFILER=true
 
mkdir mnist_torchserve
cd mnist_torchserve
mkdir config
mkdir model-store
cd ..


torch-model-archiver --model-name mnist --version 1.0 --model-file /home/ubuntu/serve/examples/image_classifier/mnist/mnist.py --serialized-file /home/ubuntu/serve/examples/image_classifier/mnist/mnist_cnn.pt --handler  /home/ubuntu/serve/examples/image_classifier/mnist/mnist_handler.py  
mv mnist.mar mnist_torchserve/model-store/

Create properties.txt in model-store

[
  {
    "model-name": "mnist",
    "version": "1.0",
    "model-file": "",
    "serialized-file": "mnist_cnn.pt",
    "extra-files": "",
    "handler": "mnist_handler.py",
    "min-workers" : 1,
    "max-workers": 3,
    "batch-size": 1,
    "max-batch-delay": 100,
    "response-timeout": 120,
    "requirements": ""
  },
  {
    "model-name": "densenet_161",
    "version": "1.0",
    "model-file": "",
    "serialized-file": "densenet161-8d451a50.pth",
    "extra-files": "index_to_name.json",
    "handler": "image_classifier",
    "min-workers" : 1,
    "max-workers": 3,
    "batch-size": 1,
    "max-batch-delay": 100,
    "response-timeout": 120,
    "requirements": ""
  }
]

Rename to properties.json

Create config.properties in mnist_torchserve/config

Upload artifacts to PVC


kubectl cp  mnist_torchserve/config model-store-pod:/pv/config
kubectl cp  mnist_torchserve/model-store model-store-pod:/pv/model-store
kubectl exec -it model-store-pod -- ls /pv

Create Torch Inference Service
https://github.com/kserve/kserve/issues/1810 

Kubectl get pods
Get name: torchserve-predictor-default-00001-deployment-5464467b4-kchxz

Wait until initialized
￼
Check files mounted correctly

kubectl logs -n default torchserve-predictor-default-00001-deployment-5464467b4-kchxz -c storage-initializer

Check if server is running
kubectl logs -f torchserve-predictor-default-00001-deployment-5464467b4-kchxz

Prepare Data

https://github.com/kserve/kserve/tree/master/docs/samples/v1beta1/torchserve/v1/imgconv#convert-image-to-bytearray

git clone https://github.com/kserve/kserve.git

cd ~/kserve/docs/samples/v1beta1/torchserve/v1/imgconv/


Run Inference
MODEL_NAME=mnist
SERVICE_HOSTNAME=$(kubectl get inferenceservice torchserve -o jsonpath='{.status.url}' | cut -d "/" -f 3)
CLUSTER_IP=localhost:8080
INPUT_PATH=@./input.json
INPUT_PATH_1=@./input_1.json
curl -v -H "Host: ${SERVICE_HOSTNAME}"  http://${CLUSTER_IP}/v1/models/${MODEL_NAME}:predict -d ${INPUT_PATH}


curl -v -H "Host: ${SERVICE_HOSTNAME}"  http://${CLUSTER_IP}/v1/models/${MODEL_NAME}:predict -d ${INPUT_PATH_1}


Densenet Test

wget https://download.pytorch.org/models/densenet161-8d451a50.pth
https://kserve.github.io/website/0.10/modelserving/v1beta1/torchserve/model-archiver/#221-create-propertiesjson-file 
torch-model-archiver --model-name densenet161 --version 1.0 --model-file /home/ubuntu/serve/examples/image_classifier/densenet_161/model.py --serialized-file densenet161-8d451a50.pth --handler image_classifier --extra-files /home/ubuntu/serve/examples/image_classifier/index_to_name.json

Update properties.json
  {
    "model-name": "densenet_161",
    "version": "1.0",
    "model-file": "",
    "serialized-file": "densenet161-8d451a50.pth",
    "extra-files": "index_to_name.json",
    "handler": "image_classifier",
    "min-workers" : 1,
    "max-workers": 3,
    "batch-size": 1,
    "max-batch-delay": 100,
    "response-timeout": 120,
    "requirements": ""
  }
Look at test.txt to see how to update config.properties

Inspiration: https://github.com/kserve/kserve/blob/07e4d5d3ea54164026bbf7d87de0b06c6d34c014/docs/samples/v1beta1/torchserve/model-archiver/model-archiver-image/dockerd-entrypoint.sh 

kubectl exec --tty model-store-pod -- cat /pv/config/config.properties

kubectl cp mnist_torchserve/model-store/densenet161.mar model-store-pod:/pv/model-store/densenet161.mar

kubectl exec --tty model-store-pod -- cat /pv/config/config.properties

kubectl cp  mnist_torchserve/model-store model-store-pod:/pv/model-store/

kubectl cp  mnist_torchserve/model-store model-store-pod:/pv/model-store


MODEL_NAME_d=densenet161

examples/image_classifier/kitten.jpg
python img2bytearray.py /home/ubuntu/serve/examples/image_classifier/kitten.jpg

mv input.json ~/cat.json
INPUT_PATH_cat=@./cat.json

curl -v -H "Host: ${SERVICE_HOSTNAME}"  http://${CLUSTER_IP}/v1/models/${MODEL_NAME_d}:predict -d ${INPUT_PATH}


# Object Detection FasterRCNN Kserve

wget https://download.pytorch.org/models/fasterrcnn_resnet50_fpn_coco-258fb6c6.pth

torch-model-archiver --model-name fasterrcnn --version 1.0 --model-file /home/ubuntu/kserve-pytorch/serve/examples/object_detector/fast-rcnn/model.py --serialized-file fasterrcnn_resnet50_fpn_coco-258fb6c6.pth --handler object_detector --extra-files /home/ubuntu/kserve-pytorch/serve/examples/object_detector/index_to_name.json

pip install torchserve nvgpu

Mkdir model-store-test
Mv fasterrcnn.mar model-store-test/
torchserve --start --model-store model-store-test/ --models fastrcnn=fasterrcnn.mar
torchserve --stop


MODEL_NAME_f=fasterrcnn
SERVICE_HOSTNAME=$(kubectl get inferenceservice torchserve -o jsonpath='{.status.url}' | cut -d "/" -f 3)
CLUSTER_IP=localhost:8080


mv input.json ~/cat.json
INPUT_PATH_cat=@./cat.json

curl -v -H "Host: ${SERVICE_HOSTNAME}"  http://${CLUSTER_IP}/v1/models/${MODEL_NAME_f}:predict -d ${INPUT_PATH_cat}

scp -i "andrew-determined-env.pem" /Users/mendeza/Downloads/faster_rcnn_e2e_checkpoints/model_8.pth ubuntu@ec2-54-90-185-179.compute-1.amazonaws.com:/home/ubuntu/kserve-pytorch


—

# Xview FasterRCNN Test

scp -i "andrew-determined-env.pem" /Users/mendeza/Downloads/faster_rcnn_e2e_checkpoints/model_8.pth ubuntu@ec2-54-90-185-179.compute-1.amazonaws.com:/home/ubuntu/kserve-pytorch

Strip model pth: notebook 

torch-model-archiver --model-name xview-fasterrcnn --version 1.0 --model-file /home/ubuntu/kserve-pytorch/serve/examples/object_detector/fast-rcnn/model-xview.py --serialized-file model_8_stripped.pth --handler /home/ubuntu/kserve-pytorch/serve/examples/object_detector/fasterrcnn_handler.py --extra-files /home/ubuntu/kserve-pytorch/serve/examples/object_detector/fast-rcnn/xview-labels/index_to_name.json

Update test.txt
Update config.properties
Add .mar to model-store
Update properties.json

kubectl cp mnist_torchserve/config/config.properties model-store-pod:/pv/config/config.properties

kubectl exec --tty model-store-pod -- cat /pv/config/config.properties

kubectl cp mnist_torchserve/model-store/xview-fasterrcnn.mar model-store-pod:/pv/model-store

kubectl exec --tty model-store-pod -- ls /pv/model-store

kubectl cp mnist_torchserve/model-store/properties.json model-store-pod:/pv/model-store

Exec into container

kubectl exec -it  torchserve-predictor-default-00001-deployment-69ff797b68-zxh7v -c kserve-container sh

ISSUE INSTALL the version that is in the container!!!

 pip install torch==1.11.0 torchvision==0.12.0

MODEL_NAME_x=xview-fasterrcnn
SERVICE_HOSTNAME=$(kubectl get inferenceservice torchserve -o jsonpath='{.status.url}' | cut -d "/" -f 3)
CLUSTER_IP=localhost:8080


mv input.json ~/cat.json
INPUT_PATH_cat=@./cat.json

curl -v -H "Host: ${SERVICE_HOSTNAME}"  http://${CLUSTER_IP}/v1/models/${MODEL_NAME_x}:predict -d ${INPUT_PATH_cat}

kserve-pytorch/serve/examples/object_detector/fast-rcnn/xview-labels/index_to_name.json