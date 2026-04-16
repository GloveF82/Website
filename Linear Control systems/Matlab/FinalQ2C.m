clear; clc; close all

syms s k
num = expand((s+2)*2);
den = expand(s*(s+1)*(s+3));
bkwyEq = simplify(diff(-den/num))
bkwyPt = double(solve(bkwyEq))
CharEq = simplify(den+k*num)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))

g = tf(sym2poly(num),sym2poly(den));

rlocus(g)
grid
set(gcf,'Position',[100,-500,750,600])

%{
k = solve(RouthArray(3,1)) % -4
crovrPt = double(solve(den+k*num))
%}