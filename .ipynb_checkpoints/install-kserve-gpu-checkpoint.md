# Install kind with gpu

Link

git clone https://github.com/jacobtomlinson/kind.git
cd kind/
git branch gpu && git pull origin gpu
make install
sudo mv /home/ubuntu/go/bin/kind /usr/local/bin/ -v

git clone https://interactivetech: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@github.com/interactivetech/kserve-pytorch.git

cd kserve-pytorch


kind create cluster --config kind-gpu.yaml

Install kubectl 

Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

https://jacobtomlinson.dev/posts/2022/running-kubeflow-inside-kind-with-gpu-support/

sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens


—
IF ON EC2 INSTANCE, NEED TO INSTALL FABRIC MANAGER
driver_version=$(nvidia-smi | grep -oP "(?<=Driver Version: )[0-9.]+")
 driver_major=$(echo ${driver_version} | cut -d. -f1)

apt-get install nvidia-fabricmanager-${driver_major}=${driver_version}* -y
apt-mark hold nvidia-fabricmanager-${driver_major}
systemctl enable nvidia-fabricmanager.service

—

Install KServe


bash kserve_install.sh

Patch
kubectl patch cm config-domain --patch '{"data":{"example.com":""}}' -n knative-serving

Deploy PVC

kubectl apply -f k8s_pvc_files/pv-and-pvc.yaml 
kubectl apply -f k8s_pvc_files/pv-and-pvc.yaml 
kubectl apply -f k8s_pvc_files/model-store-pod.yaml 


kind delete cluster --name kubeflow-gpu 


—


Wget and tar all the files

wget https://download.pytorch.org/models/densenet161-8d451a50.pth

torch-model-archiver --model-name densenet161 --version 1.0 --model-file /home/ubuntu/kserve-pytorch/serve/examples/image_classifier/densenet_161/model.py --serialized-file densenet161-8d451a50.pth --handler image_classifier --extra-files /home/ubuntu/kserve-pytorch/serve/examples/image_classifier/index_to_name.json

mv densenet161 mnist_torchserve/model-store/

wget https://download.pytorch.org/models/fasterrcnn_resnet50_fpn_coco-258fb6c6.pth

torch-model-archiver --model-name fasterrcnn --version 1.0 --model-file /home/ubuntu/kserve-pytorch/serve/examples/object_detector/fast-rcnn/model.py --serialized-file fasterrcnn_resnet50_fpn_coco-258fb6c6.pth --handler object_detector --extra-files /home/ubuntu/kserve-pytorch/serve/examples/object_detector/index_to_name.json

torch-model-archiver --model-name xview-fasterrcnn \
  --version 1.0 \
  --model-file serve/examples/object_detector/fast-rcnn/model-xview.py \
  --serialized-file trained_model_stripped.pth \
  --handler serve/examples/object_detector/fasterrcnn_handler.py  \
  --extra-files serve/examples/object_detector/fast-rcnn/xview-labels/index_to_name.json