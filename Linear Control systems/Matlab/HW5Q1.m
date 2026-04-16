clear; clc; close all

z = abs(log(0.2)/sqrt(pi^2+log(0.2)^2));
K2 = 5/3;
K1 = 3*(1+K2)^2/(8*z^2);

s = tf('s');
t = 0:0.01:10;

hold on

num = [3*K1];
den = [2,3+3*K2,3*K1];
T_s = tf(num, den);

subplot(3,1,1)
step(10*T_s)
grid on
title('Step Response [10U(t)]')

subplot(3,1,2)
step(5*T_s/s,t)
grid on
title('Ramp Response [5tU(t)]')

subplot(3,1,3)
lsim(T_s,10*sin(3*t),t)
grid on
title('Sinusoidal Response [10sin(3t)]')

set(gcf,'Position',[500,0,500,1000])