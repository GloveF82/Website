clear; clc; close all

K_p = [56,36];
hold on

for n = 1:length(K_p)
    num = [0.5*K_p(n)/(2+0.5*K_p(n))];
    den = [6/(2+0.5*K_p(n)),1];
    T_s = tf(num, den);
    step(T_s)
    grid on
end

legend('$K\_{p} = 56$','$K\_{p} = 36$','Interpreter','latex' ...
    ,'Location','south','Orientation','horizontal')