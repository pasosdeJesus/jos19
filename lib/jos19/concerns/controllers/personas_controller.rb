# frozen_string_literal: true

require "cor1440_gen/concerns/controllers/personas_controller"
require "sivel2_gen/concerns/controllers/personas_controller"

module Jos19
  module Concerns
    module Controllers
      module PersonasController
        extend ActiveSupport::Concern

        included do
          include Sivel2Gen::Concerns::Controllers::PersonasController
          include Cor1440Gen::Concerns::Controllers::PersonasController

          def atributos_show_jos19
            atributos_show_cor1440_gen + [
              :caso_ids,
            ]
          end

          def atributos_show
            atributos_show_jos19
          end

          def atributos_form_jos19
            atributos_form_cor1440_gen - 
              [:caso_ids, :familiar_ids, :familiarvictima_ids]
          end

          def atributos_form
            atributos_form_jos19
          end

          def filtro_nombresrepetidos_fechas(personas, cfecha = 'msip_persona.created_at')
            pfid = ''
            if (params[:nombresrepetidos] && params[:nombresrepetidos][:fechaini] && 
                params[:nombresrepetidos][:fechaini] != '')
              pfi = params[:nombresrepetidos][:fechaini]
              pfid = Msip::FormatoFechaHelper.fecha_local_estandar pfi
            else
              # Comenzar en semestre anterior
              pfid = Msip::FormatoFechaHelper.inicio_semestre(Date.today).to_s
            end
            personas = personas.where("#{cfecha} >= ?", pfid)
            if(params[:nombresrepetidos] && params[:nombresrepetidos][:fechafin] && 
                params[:nombresrepetidos][:fechafin] != '')
              pff = params[:nombresrepetidos][:fechafin]
              pffd = Msip::FormatoFechaHelper.fecha_local_estandar pff
              if pffd
                personas = personas.where("#{cfecha} <= ?", pffd)
              end
            end
            return personas
          end



          def consulta_nombresduplicados_autom
            depura = ''
            if ENV.fetch('DEPURA_MIN', -1).to_i > 0
              depura << " AND p1.id>#{ENV.fetch('DEPURA_MIN', -1).to_i}"
              depura << " AND p2.id>#{ENV.fetch('DEPURA_MIN', -1).to_i}"
            end
            if ENV.fetch('DEPURA_MAX', -1).to_i > 0
              depura << " AND p1.id<#{ENV.fetch('DEPURA_MAX', -1).to_i}"
              depura << " AND p2.id<#{ENV.fetch('DEPURA_MAX', -1).to_i}"
            end

            return Msip::Persona.connection.execute <<-SQL
      SELECT p1.tdocumento_id, p1.numerodocumento, 
        p1.id AS id1, p1.nombres AS nombres1, soundexespm(p1.nombres) AS sn1,
        p1.apellidos AS apellidos1, soundexespm(p1.apellidos) AS sa1,
        p2.id AS id2, p2.nombres AS nombres2, soundexespm(p2.nombres) AS sn2,
        p2.apellidos AS apellidos2, soundexespm(p2.apellidos) AS sa2
      FROM msip_persona AS p1
      JOIN msip_persona AS p2 
      ON p1.id<p2.id
        #{depura}
      WHERE
        (soundexespm(p1.nombres) = soundexespm(p2.nombres)
          AND soundexespm(p1.apellidos) = soundexespm(p2.apellidos)
        )  --con indices explain da 662.181
      --  OR 
      --  (((LENGTH(p2.nombres)>0 AND
      --      f_unaccent(p1.nombres) LIKE f_unaccent(p2.nombres) || '%')
      --    OR (LENGTH(p1.nombres)>0 AND
      --      f_unaccent(p2.nombres) LIKE f_unaccent(p1.nombres) || '%')
      --    )
      --   AND ((LENGTH(p2.apellidos)>0 AND
      --      f_unaccent(p1.apellidos) LIKE f_unaccent(p2.apellidos) || '%')
      --    OR (LENGTH(p1.apellidos)>0 AND
      --      f_unaccent(p2.apellidos) LIKE f_unaccent(p1.apellidos) || '%')
      --   )
      -- ) --no susceptible de indices con explain da 5'574.709.919
      --  OR 
      --  (levenshtein(p1.nombres || ' ' ||
      --      p1.apellidos,
      --      p2.nombres || ' ' ||
      --      p2.apellidos) <= 3
      --  ) --no encontramos como indexar con explain da 4'612.693.352
    ;
            SQL
            # Las 3 opciones sin igualdad entre tdocumento y numerodocumento da
            # 23'700.306.841 (mucho más que la suma de las opciones)
          end


          def nombresrepetidos
            @validaciones = []
            personas = Msip::Persona.all
            puts "OJO 1 personas.count=#{personas.count}"
            personas = filtro_nombresrepetidos_fechas(personas)
            res= "SELECT sub2.sigla, sub2.numerodocumento, sub2.rep, "\
              "     sub2.identificaciones[1:5] as identificaciones5, "\
              "     ARRAY(SELECT DISTINCT ac.id"\
              "     FROM cor1440_gen_asistencia AS asi"\
              "     JOIN cor1440_gen_actividad AS ac ON ac.id=asi.actividad_id "\
              "     WHERE asi.persona_id = ANY(sub2.identificaciones[2:]) "\
              "     ) AS actividades_ben,\n"\
              "     ARRAY(SELECT DISTINCT usuario.nusuario "\
              "     FROM cor1440_gen_asistencia AS asi"\
              "     JOIN msip_persona AS p2 ON p2.id=asi.persona_id "\
              "       AND p2.id = ANY(sub2.identificaciones[2:]) "\
              "     JOIN cor1440_gen_actividad AS ac ON ac.id=asi.actividad_id "\
              "     JOIN msip_bitacora AS bit ON bit.modelo='Cor1440Gen::Actividad' "\
              "       AND bit.modelo_id=ac.id "\
              "       AND DATE_PART('minute', bit.fecha-p2.created_at)<10 "\
              "     JOIN usuario ON usuario.id=bit.usuario_id "\
              "     ) AS posibles_rep\n"\
              "FROM ("\
              "     SELECT sub.sigla, sub.tdocumento_id, sub.numerodocumento, sub.rep, \n"\
              "    ARRAY(SELECT id FROM (" + personas.to_sql + ") AS p2\n"\
              "        WHERE (p2.tdocumento_id=sub.tdocumento_id OR (sub.tdocumento_id IS NULL AND p2.tdocumento_id IS NULL))\n"\
              "        AND (p2.numerodocumento=sub.numerodocumento OR (sub.numerodocumento IS NULL AND p2.numerodocumento IS NULL))\n"\
              "        ORDER BY id) AS identificaciones\n"\
              "  FROM (SELECT t.sigla, p.tdocumento_id, numerodocumento,\n"\
              "      COUNT(p.id) AS rep "\
              "      FROM (" + personas.to_sql + ") AS p\n"\
              "      LEFT JOIN msip_tdocumento as t ON t.id=tdocumento_id\n"\
              "      GROUP BY 1,2,3) AS sub\n"\
              "  WHERE rep>1\n"\
              "  ORDER BY rep DESC) AS sub2";
            arr = ActiveRecord::Base.connection.select_all(res)
            @validaciones << { 
              titulo: 'Identificaciones repetidas de personasiciarios actualizados en el rango de fechas',
              encabezado: ['Tipo Doc.', 'Núm. Doc.', 'Num. personas', 
                           'Ids 5 primeras personas', 'Ids Actividades', 
                           'Editores Act. cerca a ingreso personas'],
                           cuerpo: arr 
            }


            if params && params[:nombrerepetido] && 
                params[:nombrerepetido][:deduplicables_autom] == '1'
              arr = ActiveRecord::Base.connection.select_all(
                Jos19::UnificarHelper.consulta_casos_por_arreglar.select(['id']).to_sql
              )
              @validaciones << {
                titulo: 'Casos parcialmente eliminados por arreglar (completar o eliminar)',
                encabezado: ['Id.'],
                cuerpo: arr 
              }


              arr = ActiveRecord::Base.connection.select_all(
                Jos19::UnificarHelper.consulta_casos_en_blanco.select(['caso_id']).to_sql
              )
              @validaciones << {
                titulo: 'Casos en blanco por eliminar automaticamente',
                encabezado: ['Id.'],
                cuerpo: arr 
              }

              arr = ActiveRecord::Base.connection.select_all(
                Jos19::UnificarHelper.consulta_personas_en_blanco_por_eliminar.select(['id']).to_sql
              )
              @validaciones << {
                titulo: 'Personas en blanco por eliminar automaticamente',
                encabezado: ['Id.'],
                cuerpo: arr 
              }

              pares = consulta_paresduplicados_autom
              vc = {
                titulo: 'Beneficarios por intentar deduplicar automaticamente',
                encabezado: [
                  'T. Doc', 'Num. doc', 'Id1', 'Nombres', 'Apellidos',
                  'Id2', 'Nombres', 'Apellidos'
                ],
                cuerpo: []
              }
              pares.each do |f|
                vc[:cuerpo] << [['sigla',f['sigla']], ['numerodocumento', f['numerodocumento']],
                                ['id1', f['id1']], ['nombres1', f['nombres1']], 
                                ['apellidos1', f['apellidos1']],
                                ['id2', f['id2']], ['nombres2', f['nombres2']], 
                                ['apellidos2', f['apellidos2']] ]
              end
              @validaciones << vc
            end

            rep= "SELECT p1.id AS id1, t1.sigla, p1.numerodocumento, "\
              "     p1.nombres AS nombres1, p1.apellidos AS apellidos1,"\
              "     p2.id AS id2, t2.sigla, p2.numerodocumento, "\
              "     p2.nombres AS nombres2, p2.apellidos AS apellidos2"\
              "   FROM msip_persona AS p1"\
              "   JOIN msip_persona AS p2 ON p1.id < p2.id "\
              "   JOIN msip_tdocumento AS t1 ON p1.tdocumento_id=t1.id "\
              "   JOIN msip_tdocumento AS t2 ON p2.tdocumento_id=t2.id " \
              "   WHERE soundexespm(p1.nombres)=soundexespm(p2.nombres) AND "\
              "   soundexespm(p1.apellidos)=soundexespm(p2.apellidos) "\
              "   ORDER BY p1.nombres, p1.apellidos, p2.nombres, p2.apellidos"
            @idrep = ActiveRecord::Base.connection.select_all(rep) 

            render :nombresrepetidos, layout: 'application'
          end

          def filtro_idsrepetidas_fecha(benef, cfecha = 'msip_persona.created_at')
            pfid = ''
            if (params[:idsrepetidas] && params[:idsrepetidas][:fechaini] && 
                params[:idsrepetidas][:fechaini] != '')
              pfi = params[:idsrepetidas][:fechaini]
              pfid = Msip::FormatoFechaHelper.fecha_local_estandar pfi
            else
              # Comenzar en semestre anterior
              pfid = Msip::FormatoFechaHelper.inicio_semestre(Date.today).to_s
            end
            benef = benef.where("#{cfecha} >= ?", pfid)
            if(params[:idsrepetidas] && params[:idsrepetidas][:fechafin] && 
                params[:idsrepetidas][:fechafin] != '')
              pff = params[:idsrepetidas][:fechafin]
              pffd = Msip::FormatoFechaHelper.fecha_local_estandar pff
              if pffd
                benef = benef.where("#{cfecha} <= ?", pffd)
              end
            end
            return benef
          end


          def idsrepetidass
            @validaciones = []
            benef = Msip::Persona.all
            puts "OJO 1 benef.count=#{benef.count}"
            benef = filtro_repetidos_fecha(benef)
            res= "SELECT sub2.sigla, sub2.numerodocumento, sub2.rep, "\
              "     sub2.identificaciones[1:5] as identificaciones5, "\
              "     ARRAY(SELECT DISTINCT ac.id"\
              "     FROM cor1440_gen_asistencia AS asi"\
              "     JOIN cor1440_gen_actividad AS ac ON ac.id=asi.actividad_id "\
              "     WHERE asi.persona_id = ANY(sub2.identificaciones[2:]) "\
              "     ) AS actividades_ben,\n"\
              "     ARRAY(SELECT DISTINCT usuario.nusuario "\
              "     FROM cor1440_gen_asistencia AS asi"\
              "     JOIN msip_persona AS p2 ON p2.id=asi.persona_id "\
              "       AND p2.id = ANY(sub2.identificaciones[2:]) "\
              "     JOIN cor1440_gen_actividad AS ac ON ac.id=asi.actividad_id "\
              "     JOIN msip_bitacora AS bit ON bit.modelo='Cor1440Gen::Actividad' "\
              "       AND bit.modelo_id=ac.id "\
              "       AND DATE_PART('minute', bit.fecha-p2.created_at)<10 "\
              "     JOIN usuario ON usuario.id=bit.usuario_id "\
              "     ) AS posibles_rep\n"\
              "FROM ("\
              "     SELECT sub.sigla, sub.tdocumento_id, sub.numerodocumento, sub.rep, \n"\
              "    ARRAY(SELECT id FROM (" + benef.to_sql + ") AS p2\n"\
              "        WHERE (p2.tdocumento_id=sub.tdocumento_id OR (sub.tdocumento_id IS NULL AND p2.tdocumento_id IS NULL))\n"\
              "        AND (p2.numerodocumento=sub.numerodocumento OR (sub.numerodocumento IS NULL AND p2.numerodocumento IS NULL))\n"\
              "        ORDER BY id) AS identificaciones\n"\
              "  FROM (SELECT t.sigla, p.tdocumento_id, numerodocumento,\n"\
              "      COUNT(p.id) AS rep "\
              "      FROM (" + benef.to_sql + ") AS p\n"\
              "      LEFT JOIN msip_tdocumento as t ON t.id=tdocumento_id\n"\
              "      GROUP BY 1,2,3) AS sub\n"\
              "  WHERE rep>1\n"\
              "  ORDER BY rep DESC) AS sub2";
            arr = ActiveRecord::Base.connection.select_all(res)
            @validaciones << { 
              titulo: 'Identificaciones repetidas de beneficiarios actualizados en el rango de fechas',
              encabezado: ['Tipo Doc.', 'Núm. Doc.', 'Num. personas', 
                           'Ids 5 primeras personas', 'Ids Actividades', 
                           'Editores Act. cerca a ingreso personas'],
                           cuerpo: arr 
            }


            if params && params[:idsrepetidas] && 
                params[:idsrepetidas][:deduplicables_autom] == '1'
              arr = ActiveRecord::Base.connection.select_all(
                Jos19::UnificarHelper.consulta_casos_por_arreglar.select(
                  ['id']).to_sql
              )
              @validaciones << {
                titulo: 'Casos parcialmente eliminados por arreglar (completar o eliminar)',
                encabezado: ['Id.'],
                cuerpo: arr 
              }


              arr = ActiveRecord::Base.connection.select_all(
                Jos19::UnificarHelper.consulta_casos_en_blanco.select(
                  ['caso_id']).to_sql
              )
              @validaciones << {
                titulo: 'Casos en blanco por eliminar automaticamente',
                encabezado: ['Id.'],
                cuerpo: arr 
              }

              arr = ActiveRecord::Base.connection.select_all(
                Jos19::UnificarHelper.consulta_personas_en_blanco_por_eliminar.
                select(['id']).to_sql
              )
              @validaciones << {
                titulo: 'Personas en blanco por eliminar automaticamente',
                encabezado: ['Id.'],
                cuerpo: arr 
              }

              pares = Jos19::UnificarHelper.consulta_duplicados_autom
              vc = {
                titulo: 'Beneficarios por intentar deduplicar automaticamente',
                encabezado: [
                  'T. Doc', 'Num. doc', 'Id1', 'Nombres', 'Apellidos',
                  'Id2', 'Nombres', 'Apellidos'
                ],
                cuerpo: []
              }
              pares.each do |f|
                vc[:cuerpo] << [['sigla',f['sigla']], ['numerodocumento', f['numerodocumento']],
                                ['id1', f['id1']], ['nombres1', f['nombres1']], 
                                ['apellidos1', f['apellidos1']],
                                ['id2', f['id2']], ['nombres2', f['nombres2']], 
                                ['apellidos2', f['apellidos2']] ]
              end
              @validaciones << vc
            end

            rep= "SELECT t.sigla, p1.numerodocumento, "\
              "     p1.id AS id1, p1.nombres AS nombres1, p1.apellidos AS apellidos1,"\
              "     p2.id AS id2, p2.nombres AS nombres2, p2.apellidos AS apellidos2"\
              "   FROM msip_persona AS p1"\
              "   JOIN msip_persona AS p2 ON p1.id < p2.id "\
              "     AND p1.tdocumento_id=p2.tdocumento_id "\
              "     AND p1.numerodocumento=p2.numerodocumento "\
              "     AND p1.numerodocumento<>'' "\
              "   JOIN msip_tdocumento AS t ON p1.tdocumento_id=t.id"
            @idrep = ActiveRecord::Base.connection.select_all(rep) 

            render :idsrepetidass, layout: 'application'
          end

          def deduplicar
            if ENV.fetch('DEPURA_MIN', -1).to_i == -1 || 
                ENV.fetch('DEPURA_MAX', -1).to_i == -1
              @res_preparar_automaticamente = 
                Jos19::UnificarHelper::preparar_automaticamente
            end
            @res_deduplicar = Jos19::UnificarHelper::deduplicar_automaticamente(
              current_usuario)
            Msip::Persona.connection.execute <<-SQL
        REFRESH MATERIALIZED VIEW sivel2_gen_conscaso;
            SQL
            render :deduplicar, layout: 'application'
          end


          def unificar
            if params[:unificarpersonas]
              id1 = params[:unificarpersonas][:id1].to_i
              id2 = params[:unificarpersonas][:id2].to_i
            elsif params[:id1] && params[:id2]
              id1 = params[:id1].to_i
              id2 = params[:id2].to_i
            else
              flash[:error] = 'Faltaron identificaciones de personas a unificar'
              redirect_to Rails.configuration.relative_url_root
              return
            end

            r = Jos19::UnificarHelper.unificar_dos_personas(
              id1.dup, id2.dup, current_usuario.dup)
            m = r[0]
            p = r[1]
            if (m != "")
              flash[:error] = m
              redirect_to Rails.configuration.relative_url_root
              return
            end
            redirect_to msip.persona_path(p1)
          end


          def lista_params
            l = atributos_form + [
              :pais_id,
              :departamento_id,
              :municipio_id,
              :clase_id,
              :numerodocumento,
              :tdocumento_id,
              :ultimoperfilorgsocial_id,
              :ultimoestatusmigratorio_id,
              :ppt,
            ] +
            [
              "caracterizacionpersona_attributes" =>
              [ :id,
                "respuestafor_attributes" => [
                  :id,
                  "valorcampo_attributes" => [
                    :valor,
                    :campo_id,
                    :id,
                    :valor_ids => []
                  ]
                ] ]
            ] + [
              'proyectofinanciero_ids' => []
            ] + [ 
              "etiqueta_persona_attributes" => [
                :etiqueta_id, 
                :fecha_localizada,
                :id,
                :observaciones,
                :usuario_id,
                :_destroy
              ]
            ]
            l
          end

        end  # included

        class_methods do
        end

      end
    end
  end
end
