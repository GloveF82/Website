clear; clc; close all

syms s k
num = sym(s+5);
den = expand(s*(s+1)*(s+10));
bkwyEq = simplify(diff(-den/num))
bkwyPt = double(solve(bkwyEq))
CharEq = simplify(den+k*num)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))

g = tf(sym2poly(num),sym2poly(den));

rlocus(g)
grid

%{
k = solve(RouthArray(3,1)) % 1
crovrPt = double(solve(den+k*num))
%}