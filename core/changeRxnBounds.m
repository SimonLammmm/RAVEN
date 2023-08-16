function model = changeRxnBounds(model, rxn, value, bound)
% changeRxnBounds
%    legacy wrapper for setParam to change reaction upper/lower limits
%    model    RAVEN model object
%    rxn      reaction ID
%    value    new value for the bound to take
%    bound    'l' for lower bound, 'u' for upper bound
if bound == 'l'
    bound = 'lb';
else
    if bound == 'u'
        bound = 'ub';
    end
end
setParam(model, bound, {rxn}, [value])