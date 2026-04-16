clear; clc; close all

hold on

num = [17,200];
den = [2,20,200];
T_s = tf(num, den);
step(T_s)
grid on
