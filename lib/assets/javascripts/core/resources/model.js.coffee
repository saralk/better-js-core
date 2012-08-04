namespace "core", ->

    class @Model
    
        @attr_accessible: ->
            @_attr_accessible ?= []
            @_attr_accessible = @_attr_accessible.concat( _.toArray( arguments ) )
            
        @attr: ( attr, opts ) ->
            if typeof attr == "string"
                attr_name = attr
                attr_ty_name = opts?.attr_type
            else
                attr_name = _.keys( attr )[0]
                attr_ty_name = _.values( attr )[0]
                
            primary_key = opts?.primary_key
            primary_key ?= attr_name == "id"
            
            association = opts?.association
                
            attr_def =
                ty_name: attr_ty_name
                
            attr_def.primary_key = true unless !primary_key
            attr_def.association = true unless !association
            
            
            @_attr ?= {}
            @_attr[attr_name] = attr_def
            
        @ty_def: ->
            ty_def = attr: @_attr

            for attr_name in ( @_attr_accessible ?= [] )
                ty_def.attr[attr_name]?.accessible = true
                
            ty_def
            
        @has_many: ( association_name, opts ) ->
            @_associations ?= []
            @_associations.push( association_name )
            
            underlying_type = opts?.underlying_type
            underlying_type ?= core.support.inflector.singularize( association_name )
            
            @attr association_name,
                attr_type: "List[#{underlying_type}]"
                association: true
                
        @belongs_to: ( association_name, opts ) ->
            @has_one association_name, opts
            
            foreign_key = core.support.inflector.foreign_key( association_name )
            
            @attr foreign_key,
                attr_type: "number"
                
        @has_one: ( association_name, opts ) ->
            @_associations ?= []
            @_associations.push( association_name )
            
            underlying_type = opts?.underlying_type
            underlying_type ?= association_name
            
            @attr association_name,
                attr_type: underlying_type
                association: true        
        
        @add_validator: ( attribute, validator_name, validator_opts ) ->
            validator_class_name = "#{core.support.inflector.camelize( validator_name )}Validator"
            validator = new core.validators[validator_class_name]( attribute, validator_opts )
            @::validators ?= []
            @::validators.push( validator )
            
        @validates: ( attribute, validators ) ->
            for validator_name, validator_opts of validators
                @add_validator( attribute, validator_name, validator_opts )
                
        validate: ->
            @errors.clear()
            if @validators
                for validator in @validators
                    validator.validate( @ )
                
        is_valid: ->
            @validate()
            @errors.count == 0
        
        constructor: (data, @env) ->
            @env ?= core.Model.default_env
            @deserialize(data || {})
            @errors = new core.ModelErrors
                
        serialize: (opts) ->
            @env.serialize @class_name, @, opts?.includes
            
        deserialize: (data) ->
            @env.deserialize @class_name, data, @
        
        load: (id, opts) ->
            # env.resourceHandler.get_resource( collName, id, success: success )
            
            self = @
            env = @env
            class_name = @class_name
            collection_name = @collection_name
            
            @id(id)
            
            success = (data) ->
                env.deserialize( class_name, data, self )
                opts?.success?( self )
            
            env.repository.get_resource collection_name, id,
                _.defaults success: success, opts
                
            @

        @load_collection: (env, opts) ->
            class_name = @::class_name
            collection_name = @::collection_name
            success = (data) ->
                collection = _.map data, (el) ->
                    env.deserialize( class_name, el )
                opts?.success?( collection )

            env.repository.get_collection collection_name,
                _.defaults success: success, opts
        
        save: ( opts ) ->
            self = @
            env = @env
            opts ?= {}
            collection_name = @collection_name
            
            success = (data) ->
                self.deserialize( data )
                opts?.success?( self )
                
            if @id()
                env.repository.update_resource collection_name,
                    @id(),
                    @serialize(opts),
                    _.defaults success: success, opts
            else
                env.repository.create_resource collection_name,
                    @serialize(opts),
                    _.defaults success: success, opts
                    
        refresh: ( opts ) ->
            @load( @id(), opts )
