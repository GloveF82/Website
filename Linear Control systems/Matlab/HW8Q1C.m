clear; clc; close all

BodePaper(0.1,100,-60,20,-225,0)
set(gcf,'Position',[100,-500,1000,1000])

syms s
num = sym(s+8);
den = sym(s^2+6*s+8);
g = tf(sym2poly(num),sym2poly(den));

figure
bode(g)
grid on
set(gcf,'Position',[100,-500,1000,1000])

figure
asymp(g)
grid on
set(gcf,'Position',[100,-500,1000,1000])