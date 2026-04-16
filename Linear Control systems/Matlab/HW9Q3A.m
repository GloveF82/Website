clear; clc; close all

syms s
var = s;
num = sym(s+0.5);
den = expand(s^2*(s^2+2*s+4));
g = tf(sym2poly(num),sym2poly(den));

figure
bode(g)
grid on
set(gcf,'Position',[100,-500,1000,1000])