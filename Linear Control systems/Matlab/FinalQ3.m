clear; clc; close all

syms s k
k = 9;
num_tf = expand(k*(0.4*s+1));
den_tf = expand((s+1)*(3*s+1)*(0.4*s+1) + k);
t = tf(sym2poly(num_tf),sym2poly(den_tf))

num_ol = sym(k);
den_ol = expand((s+1)*(3*s+1)*(0.4*s+1));
g_ol = tf(sym2poly(num_ol),sym2poly(den_ol))

nyquist(g_ol)
grid on
set(gcf,'Position',[100,-500,750,600])
xlim([-1.2,0.4])
ylim([-0.5,0.5])

figure
bode(g_ol)
grid on
set(gcf,'Position',[100,-500,750,600])

figure
nichols(t)
grid on
set(gcf,'Position',[100,-500,750,600])

figure
bode(t)
grid on
set(gcf,'Position',[100,-500,750,600])

syms K
CharEq = simplify(den_ol+K*num_ol)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))
K = solve(RouthArray(3,1)) % 15.86... 