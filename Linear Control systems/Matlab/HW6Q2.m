clear; clc; close all

syms s k
num = expand((s+0.5)*(s+0.1)*(s^2+2*s+289));
zeros = solve(num)
den = expand(s*(s^2+1.45*s+361)*(s+30)^2*(s+0.8)*(s-0.4));
poles = solve(den)
bkwyEq = simplify(diff(-den/num))
bkwyPt = double(solve(bkwyEq))
CharEq = simplify(den+k*num)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))

g = tf(sym2poly(num),sym2poly(den));

rlocus(g)
grid
xlim([-35,5])
ylim([-40,40])

k = 4000;
poles_k = double(solve(den+k*num))