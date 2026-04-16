clear; clc; close all

syms s
var = s;
k = 1;
num = sym(k*(s+0.5));
den = expand(s^2*(s^2+2*s+4));
g = tf(sym2poly(num),sym2poly(den));

figure
nyquist(g)
grid on
set(gcf,'Position',[100,-500,800,650])
xlim([-1.2,0.2])