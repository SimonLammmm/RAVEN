function metaCycModel=getModelFromMetaCyc(metacycPath,keepTransportRxns,keepUnbalanced,keepUndetermined)
% getModelFromMetaCyc
%   Retrieves information stored in MetaCyc flat files and generates a super model
%
%   Input:
%   metacycPath         By setting this parameter as empty (default ''), a 
%                       super model of MetaCyc can be directly generated from
%                       the Matlab files (metaCycRxns, metaCycMets and metaCycEnzymes)
%                       that are in the RAVEN\external\metacyc directory.
%                       Alternatively, this function attempts to re-generate
%                       the Matlab files from a local dump of MetaCyc data files
%                       (e.g. reactions.dat, proteins.dat, compounds.dat),
%                       to which the path should be defined by this parameter
%   keepTransportRxns   include transportation reactions, which often have identical
%                       reactants and products that turn to be all-zero columns in
%                       the S matrix (opt, default false)
%   keepUnbalanced      include reactions cannot be unbalanced reactions, usually
%                       because they are polymeric reactions or because of a
%                       specific difficulty in balancing class structures
%                       (opt, default false)
%   keepUndetermined    include reactions that have substrates lack chemical
%                       structures or with non-numerical coefficients (e.g. n+1)
%                       (opt, default false)
%
%   Output:
%   metaCycModel        a model structure generated from MetaCyc database
%                       including all reactions, metabolites and enzymes
%                       in MetaCyc
%
%   NOTE: This function allows users to update the MetaCyc Matlab files from
%   a local dump of data files, which can be obtained through subscribing to
%   the database (https://metacyc.org/download.shtml).
%
%   Usage: getModelFromMetaCyc(metacycPath,keepTransportRxns,keepUnbalanced,keepUndetermined)

if nargin<1
    ravenPath=findRAVENroot();
    metacycPath=fullfile(ravenPath,'external','metacyc');
else
    metacycPath=char(metacycPath);
end
if nargin<2
    keepTransportRxns=false;
end
if nargin<3
    keepUnbalanced=false;
end
if nargin<4
    keepUndetermined=false;
end

%First get all reactions
metaCycModel=getRxnsFromMetaCyc(metacycPath,keepTransportRxns,keepUnbalanced,keepUndetermined);

%Get reaction and enzyme association
metaCycEnzymes=getEnzymesFromMetaCyc(metacycPath);

%Replace rxnNames with those from metaCycEnzymes
[a, b]=ismember(metaCycModel.rxns,metaCycEnzymes.rxns);
a=find(a);
b=b(a);
metaCycModel.rxnNames(a)=metaCycEnzymes.rxnNames(b);

fprintf('Reorganizing reaction-enzyme associations... ')
%Create the rxnGeneMat for the reactions, by geting all enzymes and
%corresponding subunits
rxnNum=numel(metaCycModel.rxns);
metaCycModel.genes=metaCycEnzymes.enzymes;
metaCycModel.rxnGeneMat=sparse(rxnNum,numel(metaCycEnzymes.enzymes));
metaCycModel.grRules=cell(rxnNum,1);

%Loop through all reactions to generate rxnGeneMat matrix and grRules This
%step also cross-link reactions to their catalyzing enzymes
for i=1:rxnNum
    
    metaCycModel.grRules{i}='';
    %Find out if this is an enzymatic reaction
    [a, b]=ismember(metaCycModel.rxns(i),metaCycEnzymes.rxns);
    if a
        I=[];   %Find out all catalyzing enzymes, which are treated as isoenzymes
        I=find(metaCycEnzymes.rxnEnzymeMat(b,:));
        if ~isempty(I)
            
            grRule='';
            for j=1:numel(I)
                
                subgrRule=''; %Find out if enzyme complex
                [c, d]=ismember(metaCycEnzymes.enzymes(I(j)),metaCycEnzymes.cplxs);
                if c   %In cases of an enzyme complex
                    %With single subunit
                    if numel(metaCycEnzymes.cplxComp{d}.subunit)==1
                        subgrRule=metaCycEnzymes.cplxComp{d}.subunit{1};
                        %With multiple subunits
                    else
                        subgrRule=strjoin(metaCycEnzymes.cplxComp{d}.subunit,' and ');
                        subgrRule=strcat('(',subgrRule,')');
                    end
                    [x, geneIndex]=ismember(metaCycEnzymes.cplxComp{d}.subunit,metaCycModel.genes);
                    metaCycModel.rxnGeneMat(i,geneIndex)=1;
                    
                else  %In cases of NOT an enzyme complex
                    subgrRule=metaCycEnzymes.enzymes(I(j));
                    metaCycModel.rxnGeneMat(i,I(j))=1;
                end
                
                %Generating grRules
                if ~strcmp(subgrRule,'')
                    if ~strcmp(grRule,'')
                        grRule=strcat(grRule,{' or '},subgrRule);
                    else
                        grRule=subgrRule;
                    end
                end
                
            end
            if iscell(grRule)
                metaCycModel.grRules{i}=grRule{1};
            else
                metaCycModel.grRules{i}=grRule;
            end
            
        end
        
    end
end
fprintf('done\n')
%Then get all metabolites
metaCycMets=getMetsFromMetaCyc(metacycPath);

%Add information about all metabolites to the model
[a, b]=ismember(metaCycModel.mets,metaCycMets.mets);
a=find(a);
b=b(a);

if ~isfield(metaCycModel,'metNames')
    metaCycModel.metNames=cell(numel(metaCycModel.mets),1);
    metaCycModel.metNames(:)={''};
end
metaCycModel.metNames(a)=metaCycMets.metNames(b);

if ~isfield(metaCycModel,'metFormulas')
    metaCycModel.metFormulas=cell(numel(metaCycModel.mets),1);
    metaCycModel.metFormulas(:)={''};
end
metaCycModel.metFormulas(a)=metaCycMets.metFormulas(b);

if ~isfield(metaCycModel,'metCharges')
    metaCycModel.metCharges=zeros(numel(metaCycModel.mets),1);
end
metaCycModel.metCharges(a)=metaCycMets.metCharges(b);

if ~isfield(metaCycModel,'inchis')
    metaCycModel.inchis=cell(numel(metaCycModel.mets),1);
    metaCycModel.inchis(:)={''};
end
metaCycModel.inchis(a)=metaCycMets.inchis(b);

if ~isfield(metaCycModel,'metMiriams')
    metaCycModel.metMiriams=cell(numel(metaCycModel.mets),1);
end
metaCycModel.metMiriams(a)=metaCycMets.metMiriams(b);

if ~isfield(metaCycModel,'keggid')
    metaCycModel.keggid=cell(numel(metaCycModel.mets),1);
end
metaCycModel.keggid(a)=metaCycMets.keggid(b);

%Put all metabolites in one compartment called 's' (for system). This is
%done just to be more compatible with the rest of the code
metaCycModel.comps={'s'};
metaCycModel.compNames={'System'};
metaCycModel.metComps=ones(numel(metaCycModel.mets),1);


%It could also be that the metabolite and reaction names are empty for some
%reasons. In that case, use the ID instead
I=cellfun(@isempty,metaCycModel.metNames);
metaCycModel.metNames(I)=metaCycModel.mets(I);
I=cellfun(@isempty,metaCycModel.rxnNames);
metaCycModel.rxnNames(I)=metaCycModel.rxns(I);

end
