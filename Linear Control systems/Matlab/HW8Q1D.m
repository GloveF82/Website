clear; clc; close all

BodePaper(0.1,100,-120,80,-360,0)
set(gcf,'Position',[100,-500,1000,1000])

syms s
num = expand(20*(s+8));
den = expand(s^2*(s+2)*(s+4));
g = tf(sym2poly(num),sym2poly(den));

figure
bode(g)
grid on
set(gcf,'Position',[100,-500,1000,1000])

figure
asymp(g)
grid on
set(gcf,'Position',[100,-500,1000,1000])