clear; clc; close all

syms s
var = s;
num = sym(var-8);
den = sym(var^2+6*var+8);
g = tf(sym2poly(num),sym2poly(den));

syms w real
var = 1i*w;
num = sym(var-8);
den = sym(var^2+6*var+8);

num_rat = simplify(expand(num*conj(den)));
den_rat = simplify(expand(den*conj(den)));
g_rat(w) = simplify(expand(num_rat/den_rat))
real_g_rat = real(g_rat(w))
imag_g_rat = imag(g_rat(w))
crsovr_w = solve(real_g_rat,0)
crsovr = g_rat(crsovr_w)
%{
n = inf
limit(real_g_rat,w,n)
limit(imag_g_rat,w,n)
%}

figure
nyquist(g)
grid on
set(gcf,'Position',[100,-500,800,650])