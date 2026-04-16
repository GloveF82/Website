clear; clc; close all

syms s
var = s;
num = expand(5*(var^2+1.4*var+1));
den = expand(var*(var+1)*(var+2));
g = tf(sym2poly(num),sym2poly(den));

syms w real
var = 1i*w;
num = expand(5*(var^2+1.4*var+1));
den = expand(var*(var+1)*(var+2));

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