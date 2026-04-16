clear; clc; close all

k1 = 69.75;
k2 = 4.75;
ki = 775;

routh_hurwitz([3+4*k2,4*k1+2,4*ki])