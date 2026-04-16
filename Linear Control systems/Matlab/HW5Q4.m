clear; clc; close all

K = 18000/pi;

num = [10*K 100*K];
den = [1,101,10*K+100,100*K];
g = tf(num,den);
z = zero(g)
p = pole(g)