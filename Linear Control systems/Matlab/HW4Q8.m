clear; clc; close all

K = (1:0.01:500)';
num = [K,2*K];
den = [1+0*K,6+0*K,15+K,50+2*K];

peaks = zeros(length(K),1)';
ss = zeros(length(K),1)';
PO = zeros(length(K),1);

for n = 1:length(K)
    T_s = tf(num(n,:), den(n,:));
    stepResp = step(T_s,(0:0.001:1));
    ss(n) = dcgain(T_s);    
    peaks(n) = max(stepResp);
    PO(n) = 100*abs((peaks(n)-ss(n))/ss(n));
end

figure
hold on
plot(K,PO)
PO_min = min(PO);
K_min = K(find(PO == PO_min)); %#ok<*FNDSB> 
plot(K_min,PO_min,'o')
xlabel('$K$','Interpreter','latex')
ylabel('$\textnormal{Percent Overshoot }[\%]$','Interpreter','latex')
legend('$\textnormal{Percent Overshoot vs K}$',['$\textnormal{Minimum Percent Overshoot }(K=\:$' ...
    ,num2str(K_min),'$,\:P.O.=\:$',num2str(PO_min),'$\%)$'],'Interpreter','latex')