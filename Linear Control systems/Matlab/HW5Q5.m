clear; clc; close all

k = 0.174181;
a = 1.5346;

num = [1 a];
den = [1,2*k+a,2*k*a+1];
g = tf(num,den);

step(g)
stepinfo(g)