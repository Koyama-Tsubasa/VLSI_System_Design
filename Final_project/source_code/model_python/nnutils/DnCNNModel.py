import torch
import torch.nn as nn
import torch.nn.functional as F
from collections import OrderedDict


# define a floating point model where some layers could benefit from QAT
class DnCNN(torch.nn.Module):
    def __init__(self):
        super(DnCNN, self).__init__()
        
        self.conv_relu_1 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(1, 16, 3, padding=1, padding_mode='zeros', bias=False)),
            ('relu', nn.ReLU()),
        ]))
        self.conv_relu_2 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(16, 16, 3, padding=1, padding_mode='zeros', bias=False)),
            ('relu', nn.ReLU()),
        ]))
        self.conv_relu_3 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(16, 16, 3, padding=1, padding_mode='zeros', bias=False)),
            ('relu', nn.ReLU()),
        ]))
        self.conv_relu_4 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(16, 16, 3, padding=1, padding_mode='zeros', bias=False)),
            ('relu', nn.ReLU()),
        ]))
        self.conv_relu_5 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(16, 16, 3, padding=1, padding_mode='zeros', bias=False)),
            ('relu', nn.ReLU()),
        ]))
        self.conv_relu_6 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(16, 16, 3, padding=1, padding_mode='zeros', bias=False)),
            ('relu', nn.ReLU()),
        ]))
        self.conv_7 = nn.Sequential(OrderedDict([
            ('conv', nn.Conv2d(16, 1, 3, padding=1, padding_mode='zeros', bias=False)),
        ]))

        
    def forward(self, x: torch.Tensor) -> torch.Tensor:

        x = self.conv_relu_1(x)
        x = self.conv_relu_2(x)
        x = self.conv_relu_3(x)
        x = self.conv_relu_4(x)
        x = self.conv_relu_5(x)
        x = self.conv_relu_6(x)
        out = self.conv_7(x)
        
        return out