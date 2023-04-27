torch-model-archiver --model-name xview-fasterrcnn \
  --version 1.0 \
  --model-file serve/examples/object_detector/fast-rcnn/model-xview.py \
  --serialized-file trained_model_stripped.pth \
  --handler serve/examples/object_detector/fasterrcnn_handler.py  \
  --extra-files serve/examples/object_detector/fast-rcnn/xview-labels/index_to_name.json