module Jos19
  class Ability < Sivel2Gen::Ability

    ROLADMIN  = 1
    ROLINV    = 2
    ROLDIR    = 3
    ROLCOOR   = 4
    ROLANALI  = 5
    ROLSIST   = 6

    ROLES = [
      ["Administrador", ROLADMIN], 
      ["Invitado Nacional", ROLINV], 
      ["Director Nacional", ROLDIR], 
      ["Coordinador oficina", ROLCOOR], 
      ["Analista", ROLANALI], 
      ["Sistematizador", ROLSIST],
    ]

    # Tablas básicas propias
    BASICAS_PROPIAS = [
    ]
    def tablasbasicas 
      Msip::Ability::BASICAS_PROPIAS + 
        Cor1440Gen::Ability::BASICAS_PROPIAS +
        Sivel2Gen::Ability::BASICAS_PROPIAS + BASICAS_PROPIAS - [
          ['Msip', 'fuenteprensa'],
          ['Msip', 'grupo'],
          ['Sivel2Gen', 'filiacion'],
          ['Sivel2Gen', 'frontera'],
          ['Sivel2Gen', 'intervalo'],
          ['Sivel2Gen', 'organizacion'],
          ['Sivel2Gen', 'region'],
          ['Sivel2Gen', 'sectorsocial'],
          ['Sivel2Gen', 'vinculoestado']
        ]
    end

    BASICAS_ID_NOAUTO = []
    def basicas_id_noauto 
      Msip::Ability::BASICAS_ID_NOAUTO +
        Sivel2Gen::Ability::BASICAS_ID_NOAUTO 
    end

    NOBASICAS_INDSEQID =  []
    def nobasicas_indice_seq_con_id 
      Msip::Ability::NOBASICAS_INDSEQID +
        Sivel2Gen::Ability::NOBASICAS_INDSEQID 
    end

    # Tablas básicas que deben volcarse primero --por ser requeridas por otras básicas
    BASICAS_PRIO = [
    ]
    def tablasbasicas_prio 
      Msip::Ability::BASICAS_PRIO + BASICAS_PRIO
    end


    CAMPOS_PLANTILLAS_PROPIAS = {
      'Caso' => {
        campos: [
          :caso_id,
          :contacto,
          :fecharec,
          :oficina,
          :nusuario,
          :fecha,
          :statusmigratorio,
          :ultimaatencion_fecha,
          :memo,
          :victimas
        ],
        controlador: 'Sivel2Gen::CasosController',
        ruta: '/casos'
      },
      'Consactividadcaso' => {
        solo_multiple: true,
        campos: [
          :actividad_convenios,
          :actividad_nombre,
          :actividad_fecha,
          :actividad_fecha_mes,
          :actividad_id,
          :actividad_oficina,
          :actividad_responsable,
          :caso_id,
          :caso_fecharec,
          :caso_memo,
          :es_contacto,
          :edad_hombre_r_0_5,
          :edad_hombre_r_6_12,
          :edad_hombre_r_13_17,
          :edad_hombre_r_18_26,
          :edad_hombre_r_27_59,
          :edad_hombre_r_60_,
          :edad_hombre_r_SIN,
          :edad_mujer_r_0_5,
          :edad_mujer_r_6_12,
          :edad_mujer_r_13_17,
          :edad_mujer_r_18_26,
          :edad_mujer_r_27_59,
          :edad_mujer_r_60_,
          :edad_mujer_r_SIN,
          :edad_sin_r_0_5,
          :edad_sin_r_6_12,
          :edad_sin_r_13_17,
          :edad_sin_r_18_26,
          :edad_sin_r_27_59,
          :edad_sin_r_60_,
          :edad_sin_r_SIN,
          :edad_intersexual_r_0_5,
          :edad_intersexual_r_6_12,
          :edad_intersexual_r_13_17,
          :edad_intersexual_r_18_26,
          :edad_intersexual_r_27_59,
          :edad_intersexual_r_60_,
          :edad_intersexual_r_SIN,
          :persona_apellidos,
          :persona_edad_en_atencion,
          :persona_etnia,
          :persona_id,
          :persona_nombres,
          :persona_numerodocumento,
          :persona_sexo,
          :persona_tipodocumento,
          :victima_id,
          :victima_maternidad
        ],
        controlador: 'Jos19::ConsactividadcasoController',
        ruta: '/consactividadcaso'
      }

    }

    def self.campos_plantillas 
      Heb412Gen::Ability::CAMPOS_PLANTILLAS_PROPIAS.
        clone.merge(Cor1440Gen::Ability::CAMPOS_PLANTILLAS_PROPIAS.clone.merge(
          Sivel2Gen::Ability::CAMPOS_PLANTILLAS_PROPIAS.clone.merge(
            Jos19::Ability::CAMPOS_PLANTILLAS_PROPIAS.clone)
        ))
    end

    # Autorizaciones con CanCanCan
    def initialize_sivel2_sjr(usuario = nil)
      # Sin autenticación puede consultarse información geográfica 
      can :read, [Msip::Pais, Msip::Departamento, Msip::Municipio, Msip::Clase]
      if !usuario || usuario.fechadeshabilitacion
        return
      end
      can :read, Heb412Gen::Plantillahcm
      can :read, Heb412Gen::Plantillahcr
      can :read, Heb412Gen::Plantilladoc

      can :descarga_anexo, Msip::Anexo
      can :contar, Msip::Ubicacion
      can :nuevo, Msip::Ubicacion

      can :contar, Sivel2Gen::Caso
      can :buscar, Sivel2Gen::Caso
      can :lista, Sivel2Gen::Caso
      can :nuevo, Sivel2Gen::Presponsable
      can :nuevo, Sivel2Gen::Victima

      if !usuario.nil? && !usuario.rol.nil? then
        can :read, Msip::Persona
        can :read, Heb412Gen::Doc
        case usuario.rol 
        when Ability::ROLINV
          cannot :buscar, Sivel2Gen::Caso
          can :read, Sivel2Gen::Caso 

        when Ability::ROLSIST
          can [:update, :create, :destroy], Cor1440Gen::Actividad, 
            oficina: { id: usuario.oficina_id}
          can [:read, :new], Cor1440Gen::Actividad
          can [:index, :read], Cor1440Gen::Proyectofinanciero

          can :manage, Msip::Persona
          can [:new, :read, :edit, :update, :create], 
            Msip::Orgsocial
          can :manage, Msip::Persona

          can :manage, Sivel2Gen::Acto
          can :read, Sivel2Gen::Caso, 
            casosjr: { oficina_id: usuario.oficina_id }
          can [:update, :create, :destroy], Sivel2Gen::Caso, 
            casosjr: { asesor: usuario.id, oficina_id:usuario.oficina_id }
          can :new, Sivel2Gen::Caso 

          can :read, Jos19::Consactividadcaso

        when Ability::ROLANALI
          can :read, Cor1440Gen::Actividad
          can :new, Cor1440Gen::Actividad
          can [:update, :create, :destroy], Cor1440Gen::Actividad, 
            oficina: { id: usuario.oficina_id}
          can :read, Cor1440Gen::Informe
          can [:index, :read], Cor1440Gen::Proyectofinanciero

          can [:new, :read, :edit, :update, :create], 
            Msip::Orgsocial
          can :manage, Msip::Persona

          can :manage, Sivel2Gen::Acto
          can :read, Sivel2Gen::Caso
          can :new, Sivel2Gen::Caso
          can [:update, :create, :destroy], Sivel2Gen::Caso, 
            casosjr: { oficina_id: usuario.oficina_id }

          can :read, Jos19::Consactividadcaso

        when Ability::ROLCOOR
          can [:read, :manage], Usuario, oficina: { id: usuario.oficina_id}

          can :manage, Cor1440Gen::Informe
          can :read, Cor1440Gen::Actividad
          can :new, Cor1440Gen::Actividad
          can [:index, :read], Cor1440Gen::Proyectofinanciero
          can [:update, :create, :destroy], Cor1440Gen::Actividad, 
            oficina: { id: usuario.oficina_id}

          can :manage, Msip::Orgsocial
          can :manage, Msip::Persona

          can :manage, Sivel2Gen::Acto
          can :read, Sivel2Gen::Caso
          can :new, Sivel2Gen::Caso
          can [:update, :create, :destroy, :poneretcomp], Sivel2Gen::Caso, 
            casosjr: { oficina_id: usuario.oficina_id }

          can :read, Jos19::Consactividadcaso

        when Ability::ROLADMIN, Ability::ROLDIR
          can :manage, ::Usuario

          can :manage, Cor1440Gen::Actividad
          can :manage, Cor1440Gen::Informe
          can :manage, Cor1440Gen::Proyectofinanciero

          can :manage, Heb412Gen::Plantillahcm
          can :manage, Heb412Gen::Plantillahcr
          can :manage, Heb412Gen::Plantilladoc

          can :manage, Mr519Gen::Formulario

          can :manage, Msip::Orgsocial
          can :manage, Msip::Persona

          can :manage, Sivel2Gen::Acto
          can :manage, Sivel2Gen::Caso

          can :read, Jos19::Consactividadcaso

          can :manage, :tablasbasicas
          tablasbasicas.each do |t|
            c = Ability.tb_clase(t)
            can :manage, c
          end
        end
      end
    end

  end
end
