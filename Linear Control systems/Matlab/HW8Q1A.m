clear; clc; close all

BodePaper(0.01,100,-60,20,-225,0)
set(gcf,'Position',[100,-500,1000,1000])

syms s
num = sym(12);
den = expand((s+4)*(s+(1/3)));
g = tf(sym2poly(num),sym2poly(den));

figure
bode(g)
grid on
set(gcf,'Position',[100,-500,1000,1000])

figure
asymp(g)
grid on
set(gcf,'Position',[100,-500,1000,1000])