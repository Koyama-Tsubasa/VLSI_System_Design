import torch
import torch.nn as nn
from torch.utils.data import DataLoader
import torch.optim as optim

def add_noise(inputs,noise_factor=0.3):
    noise = inputs+torch.randn_like(inputs)*noise_factor
    # noise = torch.clip(noise,0.,1.)
    return noise

def test(model: nn.Module, dataloader: DataLoader, max_samples=None, device=torch.device('cpu'), t=0) -> float:

    with torch.no_grad():

        out = []
        label = []

        for data in dataloader:

            # images, labels = data[0].to(device), data[1].to(device)

            images = data[0].to(device)

            noisy = add_noise(images).to(device) 

            outputs = model(noisy)

            # Append the network output and the original image to the lists
            out.append(outputs.cpu())
            label.append(images.cpu())

        # Create a single tensor with all the values in the lists
        out = torch.cat(out)
        label = torch.cat(label)
        if (t):
            out = ((out+128)/255)*2 - 1

        # Evaluate global loss
        val_loss = nn.MSELoss()(out, label)

    return val_loss.data
