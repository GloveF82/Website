clear; clc; close all

BodePaper(0.1,100,-40,40,-135,90)
set(gcf,'Position',[100,-500,1000,1000])

syms s
num = expand(5*(s^2+1.4*s+1));
den = expand(s*(s+1)*(s+2));
g = tf(sym2poly(num),sym2poly(den));

figure
bode(g)
grid on
set(gcf,'Position',[100,-500,1000,1000])

figure
asymp(g)
grid on
set(gcf,'Position',[100,-500,1000,1000])