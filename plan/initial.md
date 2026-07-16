ok, so rn the team is working on standards and fixed vocabulary for their experiments,
rn the data is expressed as flattend spreadsheets, using DataHarmonizer, which is ok for user input but far from perfect, whith the idea that admins would edit the schema docs directly which means that they are using the data schemas as the sole entry point for vocab/ standardization ( this is flawd and comprimising all of the tools in use)
the bigest restriction is that no mater how far we abstract, the realized result will need to be compatible with the tools they use i.e. data harmonizer and data catalog unless we can get them to switch

- current state
    - data either is given to us in arbitrary formats ( spreadsheets) or we or user enters it with dataharmonizer

i want to redesign/create abstraction layers that seperate data schema from fixed terminology to make a simpler exposure to admins maintaining terminology, it could be as simple as a couple of odfs they maintian that are refferenced from the schemas

the other part is abstracting the schemas into optimized is_a and nested forms that data is in on the backend, 
    and then we have schemase for transforming data into other forms ( for the simpleset tidy verse style transformation that flatten nested and merge nested names to new names to make an csv or spreadsheet) 
        1. to spreadsheets compatible with dataharmonizer
        2. to forms compatible to arbitrary internal tools
            - for user to fill out info that can be applied to either non duplicated singular elements (like a data set, or unique plate, or unique recipe) or mapped to  set of elements
        3. back to whatever version of linkml dataharmonizer compatible they are making the source examples that we want to move away from to show them it still works