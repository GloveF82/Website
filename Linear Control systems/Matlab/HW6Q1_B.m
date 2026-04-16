clear; clc; close all

syms s k
num = sym(1);
den = expand((s^2+2*s+2)*(s+2));
bkwyEq = simplify(diff(-den/num))
bkwyPt = double(solve(bkwyEq))
CharEq = simplify(den+k*num)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))

g = tf(sym2poly(num),sym2poly(den));

rlocus(g)
grid

%{
k = solve(RouthArray(n,1)) % 
crovrPt = double(solve(den+k*num))
%}