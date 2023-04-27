kubectl cp mnist_torchserve/model-store/ model-store-pod:/pv/model-store
kubectl cp mnist_torchserve/config/ model-store-pod:/pv/config
kubectl exec --tty model-store-pod -- ls /pv/config
kubectl exec --tty model-store-pod -- ls /pv/model-store