clear; clc; close all

syms s k
var = s;
num = sym((s+0.5));
den = expand(s^2*(s^2+2*s+4));
g = tf(sym2poly(num),sym2poly(den));
CharEq = simplify(den+k*num)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))

figure
rlocus(g)
grid on
set(gcf,'Position',[100,-500,800,650])
xlim([-1.5,0.5])