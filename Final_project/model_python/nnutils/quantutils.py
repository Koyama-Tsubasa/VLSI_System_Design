from copy import deepcopy
import torch.nn as nn
import torch
from typing import Tuple
from typing import List
import numpy as np
import math
import torch.nn.functional as F


def copy_model(model: nn.Module) -> nn.Module:
    result = deepcopy(model)

    # Copy over the extra metadata we've collected which copy.deepcopy doesn't capture
    if hasattr(model, 'input_activations'):
        result.input_activations = deepcopy(model.input_activations)

    for result_layer, original_layer in zip(result.modules(), model.modules()):
        if isinstance(result_layer, nn.Conv2d) or isinstance(result_layer, nn.Linear):
            if hasattr(original_layer.weight, 'scale'):
                result_layer.weight.scale = deepcopy(
                    original_layer.weight.scale)

        if hasattr(original_layer, 'inAct'):
            result_layer.inAct = deepcopy(original_layer.inAct)
        if hasattr(original_layer, 'outAct'):
            result_layer.outAct = deepcopy(original_layer.outAct)
        if hasattr(original_layer, 'output_scale'):
            result_layer.output_scale = deepcopy(original_layer.output_scale)

    return result


def quantized_weights(weights: torch.Tensor) -> Tuple[torch.Tensor, float]:
    '''
    Quantize the weights so that all values are integers between -128 and 127.
    Use the total range when deciding just what factors to scale the float32 
    values by.

    Parameters:
    weights (Tensor): The unquantized weights

    Returns:
    (Tensor, float): A tuple with the following elements:
        * The weights in quantized form, where every value is an integer between -128 and 127.
          The "dtype" will still be "float", but the values themselves should all be integers.
        * The scaling factor that your weights were multiplied by.
          This value does not need to be an 8-bit integer.
    '''
    
    size = weights.size()
    weight = weights.cpu().view(-1).numpy().tolist()
    max_weight = max(weight)
    min_weight = abs(min(weight))
    if max_weight<min_weight:
        max_weight = min_weight
        min_weight = (-1)*min_weight
    else:
        min_weight = (-1)*max_weight
  
    S = (127-(-128))/(max_weight-min_weight)
    
    for w in range(len(weight)):
        weight[w] = round((weight[w])*S)
    
    weight = np.reshape(weight,size)
    weights = torch.Tensor(weight)
    weights = torch.clamp(weights, -128, 127)
    
    return weights, S


def quantize_layer_weights(model: nn.Module, device):
    for layer in model.modules():
        if isinstance(layer, nn.Conv2d) or isinstance(layer, nn.Linear):
            
            q_layer_data, scale = quantized_weights(layer.weight.data)
            q_layer_data = q_layer_data.to(device)
            
            layer.weight.data = q_layer_data
            layer.weight.scale = scale
            
            if (q_layer_data < -128).any() or (q_layer_data > 127).any():
                raise Exception(
                    "Quantized weights of {} layer include values out of bounds for an 8-bit signed integer".format(layer.__class__.__name__))
            if (q_layer_data != q_layer_data.round()).any():
                raise Exception(
                    "Quantized weights of {} layer include non-integer values".format(layer.__class__.__name__))


class NetQuantized(nn.Module):
    def __init__(self, net_with_weights_quantized: nn.Module):
        super(NetQuantized, self).__init__()

        net_init = copy_model(net_with_weights_quantized)

        self.conv_relu_1 = net_init.conv_relu_1
        self.conv_relu_2 = net_init.conv_relu_2
        self.conv_relu_3 = net_init.conv_relu_3
        self.conv_relu_4 = net_init.conv_relu_4
        self.conv_relu_5 = net_init.conv_relu_5
        self.conv_relu_6 = net_init.conv_relu_6
        self.conv_7 = net_init.conv_7

        for layer in self.conv_relu_1, self.conv_relu_2, self.conv_relu_3, self.conv_relu_4, self.conv_relu_5, self.conv_relu_6, self.conv_7:
            def pre_hook(l, x):
                x = x[0]
                if (x < -128).any() or (x > 127).any():
                    raise Exception(
                        "Input to {} layer is out of bounds for an 8-bit signed integer".format(l.__class__.__name__))
                if (x != x.round()).any():
                    raise Exception(
                        "Input to {} layer has non-integer values".format(l.__class__.__name__))
            layer.register_forward_pre_hook(pre_hook)

        # Calculate the scaling factor for the initial input to the CNN
        self.input_activations = net_with_weights_quantized.conv_relu_1.inAct
        self.input_scale = NetQuantized.quantize_initial_input(
            self.input_activations)

        # Calculate the output scaling factors for all the layers of the CNN
        preceding_layer_scales = []
        for layer in self.conv_relu_1, self.conv_relu_2, self.conv_relu_3, self.conv_relu_4, self.conv_relu_5, self.conv_relu_6, self.conv_7:
            layer.output_scale = NetQuantized.quantize_activations(
                layer.outAct, layer[0].weight.scale, self.input_scale, preceding_layer_scales)
            preceding_layer_scales.append(
                (layer[0].weight.scale, layer.output_scale))

    @staticmethod
    def quantize_initial_input(pixels: np.ndarray) -> float:
        '''
        Calculate a scaling factor for the images that are input to the first layer of the CNN.

        Parameters:
        pixels (ndarray): The values of all the pixels which were part of the input image during training

        Returns:
        float: A scaling factor that the input should be multiplied by before being fed into the first layer.
               This value does not need to be an 8-bit integer.
        '''

        max_pixel = max(pixels)
        min_pixel = abs(min(pixels))
        if max_pixel<min_pixel:
            max_pixel = min_pixel
            min_pixel = (-1)*min_pixel
        else:
            min_pixel = (-1)*max_pixel
            
        S = (127-(-128))/(max_pixel-min_pixel)
        
        return S

    @staticmethod
    def quantize_activations(activations: np.ndarray, n_w: float, n_initial_input: float, ns: List[Tuple[float, float]]) -> float:
        '''
        Calculate a scaling factor to multiply the output of a layer by.

        Parameters:
        activations (ndarray): The values of all the pixels which have been output by this layer during training
        n_w (float): The scale by which the weights of this layer were multiplied as part of the "quantize_weights" function you wrote earlier
        n_initial_input (float): The scale by which the initial input to the neural network was multiplied
        ns ([(float, float)]): A list of tuples, where each tuple represents the "weight scale" and "output scale" (in that order) for every preceding layer

        Returns:
        float: A scaling factor that the layer output should be multiplied by before being fed into the next layer.
               This value does not need to be an 8-bit integer.
        '''
       
        max_activations = max(activations)
        min_activations = abs(min(activations))
        if max_activations<min_activations:
            max_activations = min_activations
            min_activations = (-1)*min_activations
        else:
            min_activations = (-1)*max_activations
            
        nol = (127-(-128))/(max_activations-min_activations)
        s = 1
        for i in ns:
            for scales in i:
                s = s * scales
                    
        Sl = nol/(n_initial_input*n_w*s)
        
        return Sl

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        '''
        Please follow these steps whenever processing with input/output scale to scale the input/outputs of each layer:
            * scale = round(scale*(2**16))
            * (scale*features) >> 16
            * Clamp the value between -128 and 127

        To make sure that the intial input and the outputs of each layer are integers between -128 and 127, you may need to use the following functions:
            * torch.Tensor.round
            * torch.clamp
        '''
        
        input_scale = torch.Tensor.round(self.input_scale*(2**16))
        x = torch.floor((x*input_scale)/(2**16))
        x = torch.clamp(x, -128, 127)
        x = self.conv_relu_1(x)
        
        scale_conv_relu_2 = torch.Tensor.round(self.conv_relu_1.output_scale*(2**16))
        x = torch.floor((x*scale_conv_relu_2)/(2**16))
        x = torch.clamp(x, -128, 127)
        x = self.conv_relu_2(x)
        
        scale_conv_relu_3 = torch.Tensor.round(self.conv_relu_2.output_scale*(2**16))
        x = torch.floor((x*scale_conv_relu_3)/(2**16))
        x = torch.clamp(x, -128, 127)
        x = self.conv_relu_3(x)
        
        scale_conv_relu_4 = torch.Tensor.round(self.conv_relu_3.output_scale*(2**16))
        x = torch.floor((x*scale_conv_relu_4)/(2**16))
        x = torch.clamp(x, -128, 127)
        x = self.conv_relu_4(x)
        
        scale_conv_relu_5 = torch.Tensor.round(self.conv_relu_4.output_scale*(2**16))
        x = torch.floor((x*scale_conv_relu_5)/(2**16))
        x = torch.clamp(x, -128, 127)
        x = self.conv_relu_5(x)
        
        scale_conv_relu_6 = torch.Tensor.round(self.conv_relu_5.output_scale*(2**16))
        x = torch.floor((x*scale_conv_relu_6)/(2**16))
        x = torch.clamp(x, -128, 127)
        x = self.conv_relu_6(x)
        
        scale_conv_7_in = torch.Tensor.round(self.conv_relu_6.output_scale*(2**16))
        x = torch.floor((x*scale_conv_7_in)/(2**16))
        x = torch.clamp(x, -128, 127)
        x = self.conv_7(x)
        
        scale_conv_7_out = torch.Tensor.round(self.conv_7.output_scale*(2**16))
        x = torch.floor((x*scale_conv_7_out)/(2**16))
        out = torch.clamp(x, -128, 127)
        
        return out
