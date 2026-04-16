clear; clc; close all

hold on

num = [100];
den = [1,10,100];
T_s = tf(num, den);
step(T_s)
grid on