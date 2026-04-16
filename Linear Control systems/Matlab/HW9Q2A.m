clear; clc; close all

syms s k
var = s;
num = sym(1);
den = expand(s*(s+2)*(s+10));
g = tf(sym2poly(num),sym2poly(den));
CharEq = simplify(den+k*num)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))

figure
nyquist(g)
grid on
set(gcf,'Position',[100,-500,800,650])
% ylim([-1,1])
% xlim([-3,1])