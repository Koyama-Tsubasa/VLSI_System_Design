import torch
import torch.nn as nn
from torch.utils.data import DataLoader
import torch.optim as optim

def add_noise(inputs,noise_factor=0.3):
    noise = inputs+torch.randn_like(inputs)*noise_factor
    # noise = torch.clip(noise,0.,1.)
    return noise

def train(model: nn.Module, dataloader: DataLoader, device):

    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    r = 100
    for epoch in range(r):  # loop over the dataset multiple times

        running_loss = 0.0
        for i, data in enumerate(dataloader):

            # get the inputs; data is a list of [inputs, labels]
            # inputs, labels = data[0].to(device), data[1].to(device)
#             for name, param in model.named_parameters():
#                 print(param)
            inputs = data[0].to(device)

            noisy = add_noise(inputs).to(device) 

            # zero the parameter gradients
            optimizer.zero_grad()

            # forward + backward + optimize
            outputs = model(noisy)
            loss = criterion(outputs, inputs)
            loss.backward()
            optimizer.step()

            # print statistics
            running_loss += loss.item()
#             if i % 100 == 99:    # print every 100 mini-batches
#                 print('[%d, %5d] loss: %.6f' %
#                       (epoch + 1, i + 1, running_loss / 100))
#                 running_loss = 0.0
        print('[ epoch',str(epoch+1),'] loss: %.6f' %(running_loss / i))
        if (running_loss / i < 0.0065):
            break

    print('Finished Training')
