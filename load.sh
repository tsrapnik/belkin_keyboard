make
sudo rmmod hid-apple
sudo insmod hid-apple.ko
sudo dmesg -w | grep type