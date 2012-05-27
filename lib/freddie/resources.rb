module Freddie
  module Resources
    module ApplicationExtensions
      def resource(klass, options = {}, &blk)
        invoke Freddie::Resources::ResourceMounter, options.merge(:class => klass), &blk
      end
    end

    class ResourceMounter < Freddie::Application
      INDEX_PERMISSIONS   = [:index, :view, :manage]
      SHOW_PERMISSIONS    = [:show, :view, :manage]
      NEW_PERMISSIONS     = [:new, :create, :manage]
      CREATE_PERMISSIONS  = [:create, :manage]
      EDIT_PERMISSIONS    = [:edit, :update, :manage]
      UPDATE_PERMISSIONS  = [:update, :manage]
      DESTROY_PERMISSIONS = [:destroy, :manage]

      def render_resource_template(name)
        render "#{options[:plural_name]}/#{name}.html.haml"
      end

      def resource
        options[:class]
      end

      def resource_with_permission_scope(*whats)
        if p = context.permissions.find_permission(*whats, options[:class])
          if p.is_a?(Hash)
            resource.where(p)
          elsif p.is_a?(Proc)
            (p.arity == 0 ? resource.instance_exec(&p) : resource.call(r))
          else
            resource
          end
        else
          resource.where(false)
        end
      end

      def require_permission!(*args)
        raise "not allowed" unless can?(*args, options[:class])
      end

      def set_plural_variable(v)
        context.instance_variable_set "@#{options[:plural_name]}", v
      end

      def plural_variable
        context.instance_variable_get "@#{options[:plural_name]}"
      end

      def set_singular_variable(v)
        context.instance_variable_set "@#{options[:singular_name]}", v
      end

      def singular_variable
        context.instance_variable_get "@#{options[:singular_name]}"
      end

      def do_index
        require_permission! INDEX_PERMISSIONS
        set_plural_variable resource_with_permission_scope(INDEX_PERMISSIONS).all
        render_resource_template 'index'
      end

      def do_show
        require_permission! SHOW_PERMISSIONS
        set_singular_variable resource_with_permission_scope(SHOW_PERMISSIONS).find(params['id'])
        render_resource_template 'show'
      end

      def do_new
        require_permission! NEW_PERMISSIONS
        set_singular_variable resource_with_permission_scope(NEW_PERMISSIONS).new
        render_resource_template 'new'
      end

      def do_create
        require_permission! CREATE_PERMISSIONS
        set_singular_variable resource_with_permission_scope(CREATE_PERMISSIONS).new(params[options[:singular_name]])

        if singular_variable.save
          redirect! singular_variable
        else
          render_resource_template 'new'
        end
      end

      def do_edit
        require_permission! EDIT_PERMISSIONS
        set_singular_variable resource_with_permission_scope(EDIT_PERMISSIONS).find(params['id'])
        render_resource_template 'edit'
      end

      def do_update
        require_permission! UPDATE_PERMISSIONS
        set_singular_variable resource_with_permission_scope(UPDATE_PERMISSIONS).find(params['id'])
        singular_variable.attributes = params[options[:singular_name]]

        if singular_variable.save
          redirect! singular_variable
        else
          render_resource_template 'edit'
        end
      end

      def route
        @options = {
          singular_name: options[:class].to_s.tableize.singularize,
          plural_name:   options[:class].to_s.tableize.pluralize
        }.merge(@options)

        path options[:plural_name] do
          get('new') { do_new }

          path :id do
            get         { do_show }
            post        { do_update }
            get('edit') { do_edit }
          end

          post { do_create }
          get  { do_index }
        end
      end
    end
  end
end

Freddie::Application.send(:include, Freddie::Resources::ApplicationExtensions)