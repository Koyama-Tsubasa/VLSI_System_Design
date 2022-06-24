import nnutils.train
import nnutils.test
import nnutils.DnCNNModel
import nnutils.quantutils
train = nnutils.train.train
test = nnutils.test.test
DnCNN = nnutils.DnCNNModel.DnCNN
# LeNet = nnutils.LeNetModel.LeNet
# LeNet_with_bias = nnutils.LeNetModel.LeNet_with_bias
copy_model = nnutils.quantutils.copy_model
# quantize_layer_weights = nnutils.quantutils.quantize_layer_weights
NetQuantized = nnutils.quantutils.NetQuantized
# NetQuantizedWithBias = nnutils.quantutils.NetQuantizedWithBias
