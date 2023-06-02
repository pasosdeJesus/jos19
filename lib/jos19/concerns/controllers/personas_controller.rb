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

          def atributos_index_jos19
            atributos_show - [:familiares]
          end

          def atributos_index
            a = atributos_index_jos19
            a
          end

          def atributos_form_jos19
            a = atributos_form_cor1440_gen - [
              :caso_ids, 
              :familiar_ids, 
              :familiares, 
              :familiarvictima_ids
            ] + [
              :persona_trelacion1
            ]
            return a
          end

          def atributos_form
            atributos_form_jos19
          end

          def vistas_manejadas
            ['Persona']
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
            sinhom = ''
            if ActiveRecord::Base.connection.table_exists?('msip_homonimo')
              sinhom = "   AND (p1.id, p2.id) NOT IN "\
                "     (SELECT  persona1_id, persona2_id FROM msip_homonimo)"
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
              "   soundexespm(p1.apellidos)=soundexespm(p2.apellidos) " + 
              sinhom +
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


          # Unificar dos casos, eliminando el de código mayor y dejando
          # su información como etiqueta en el primero
          # @return caso_id donde unifica si lo logra o nil
          def unificar_dos_casos(c1_id, c2_id, current_usuario, menserror)
            tmenserror = ''
            if !c1_id || c1_id.to_i <= 0 ||
                Sivel2Gen::Caso.where(id: c1_id.to_i).count == 0
              tmenserror << "Primera identificación de caso no válida '#{c1_id.to_s}'.\n"
            end
            if !c2_id || c2_id.to_i <= 0 ||
                Sivel2Gen::Caso.where(id: c2_id.to_i).count == 0
              tmenserror << "Segunda identificación de caso no válida '#{c2_id.to_s}'.\n"
            end
            if c1_id.to_i == c2_id.to_i
              tmenserror << "Primera y segunda identificación son iguales, no unificando.\n"
            end

            if tmenserror != ""
              menserror << tmenserror
              return nil
            end

            c1 = Sivel2Gen::Caso.find([c1_id.to_i, c2_id.to_i].min)
            c2 = Sivel2Gen::Caso.find([c1_id.to_i, c2_id.to_i].max)

            eunif = Msip::Etiqueta.where(
              nombre: Rails.configuration.x.jos19_etiquetaunificadas).take
              if !eunif
                tmenserror << "No se encontró etiqueta "\
                  "#{Rails.configuration.x.jos19_etiquetaunificadas}.\n"
              end

              if tmenserror != ""
                menserror << tmenserror
                return nil
              end

              ep = Sivel2Gen::CasoEtiqueta.new(
                caso_id: c1.id,
                etiqueta_id: eunif.id,
                usuario_id: current_usuario.id,
                fecha: Date.today(),
                observaciones: ""
              )

              Sivel2Sjr::ActividadCasosjr.where(casosjr_id: c2.id).each do |ac|
                ac.casosjr_id = c1.id
                ac.save
                ep.observaciones << "Cambiado caso beneficiario en actividad #{ac.id}\n"
              end

              ep.observaciones = ep.observaciones[0..9999]
              ep.save
              cc = Sivel2Sjr::CasosController.new
              c2rep = UnificarHelper.reporte_md_contenido_objeto("Caso #{c1.id}", cc.lista_params, c1, 0)
              c2id = c2.id
              if eliminar_caso(c2, tmenserror)
                ep.observaciones << "Se unificó y eliminó el registro de caso #{c2id}\n" +
                  ep.observaciones << c2rep
              else
                ep.observaciones << "No se logró eliminar el caso #{c2id}, pero si se unficó en el #{c1.id}\n" +
                  tmenserror << "No se logró eliminar el caso #{c2id}\n"
              end
              ep.observaciones = ep.observaciones[0..9999]
              begin
                ep.save!
              rescue Exception => e
                puts e.to_s
              end


              if tmenserror != ""
                menserror << tmenserror
                return nil
              end

              return c1.id
          end

          # @param p1 Primera persona
          # @param p2 Segunda persona
          # @param ep Etiqueta para la persona que queda que se construye
         def unificar_dos_personas_en_casos(
           p1, p2, current_usuario, cadpersona, ep, menserror
         )

           cp2 = Sivel2Gen::Victima.where(persona_id: p2.id).pluck(:caso_id)
           cp2.each do |cid|
             Sivel2Gen::Victima.where(
               caso_id: cid, persona_id: p2.id
             ).each do |vic|
               if Sivel2Gen::Victima.where(
                   caso_id: cid, persona_id: p1.id).count == 0
                 nv = vic.dup
                 nv.persona_id = p1.id
                 nv.save
                 ep.observaciones << "Creada víctma en caso #{cid}\n"
               end
               ep.save
               #cr = unificar_dos_casos(cc1[0], cc2[0], current_usuario, menserror)
               #if !cr.nil?
               #  ep.observaciones << "Unificados casos #{cc1[0]} y #{cc2[0]} en #{cr}\n"
               #else
               #  menserror << "Primer #{cadpersona} (#{p1.id} "\
               #    "#{p1.nombres.to_s} #{p1.apellidos.to_s}) es contacto "\
               #    "en caso #{cc1[0]} y segundo beneficiario (#{p2.id} "\
               #    "#{p2.nombres} #{p2.apellidos}) es contacto en caso "\
               #    "#{cc2[0]}. Se intentó sin éxito la unificación de "\
               #    "los dos casos.\n"
               #  return [menserror, nil]
               #end
               Sivel2Gen::Acto.where(
                 caso_id: cid, persona_id: p2.id
               ).each do |ac|
                 ac.persona_id = p1.id
                 ac.save!
                 ep.observaciones << "Cambiado acto en caso #{cid}\n"
               end
               ep.save
               ep.observaciones << "Elimina #{cadpersona} "\
                 "#{vic.persona_id} del caso #{cid}\n"
               vic.destroy
               ep.observaciones = ep.observaciones[0..4998]
               ep.save
             end
           end
         end



          # Unificar la información de una segunda persona en una 
          # primera y elimina la segunda
          #
          # @return [menserror, null] si hay error o ["", persona_id] si no
          def unificar_dos_personas(
            p1_id, p2_id, current_usuario, cadpersona="persona")
            menserror = ''.dup
            if !p1_id || p1_id.to_i <= 0 ||
                Msip::Persona.where(id: p1_id.to_i).count == 0
              menserror += "Primera identificación de #{cadpersona} no válida "\
                "#{p1_id.to_s}.\n"
            end
            if !p2_id || p2_id.to_i <= 0 ||
                Msip::Persona.where(id: p2_id.to_i).count == 0
              menserror += "Segunda identificación de #{cadpersona} no válida "\
                "#{p2_id.to_s}.\n"
            end
            if p1_id.to_i == p2_id.to_i
              menserror += "Primera y segunda identificación son iguales, "\
                "no se unifican.\n"
            end
            if menserror != ""
              return [menserror, nil]
            end

            p1 = Msip::Persona.find([p1_id.to_i, p2_id.to_i].min)
            p2 = Msip::Persona.find([p1_id.to_i, p2_id.to_i].max)

            cp1 = Sivel2Gen::Victima.where(persona_id: p1.id).pluck(:caso_id)
            cp2 = Sivel2Gen::Victima.where(persona_id: p2.id).pluck(:caso_id)
            cc = cp1 & cp2
            if cc.count == 1
              menserror += "El caso #{cc.first} tiene ambos #{cadpersona}s "\
                "como víctimas; por previción antes debe eliminar alguna "\
                "de esas víctimas de ese caso.\n"
            elsif cc.count > 1
              menserror += "Los casos #{cc.inspect} tienen a ambos "\
                "#{cadpersona} como víctimas; por previción antes en "\
                "cada uno de esos casos debe eliminar alguna "\
                "de las dos víctimas.\n"
            end

            ap1 = Cor1440Gen::Asistencia.where(persona_id: p1.id).
              pluck(&:actividad_id)
            ap2 = Cor1440Gen::Asistencia.where(persona_id: p2.id).
              pluck(&:actividad_id)
            ac = ap1 & ap2
            if ac.count == 1
              menserror += "La actividad #{ac.first} tiene ambos "\
                "#{cadpersona}s como asistentes; por previción antes "\
                "debe eliminar alguno de los asistentes duplicados "\
                "de esa actividad.\n"
            elsif ac.count > 1
              menserror += "Las actividades #{ac.inspect} tienen a ambos "\
                "#{cadperson}s como asistentes; por previción antes en "\
                "cada una de esas actividades debe eliminar alguno "\
                "de los dos asistentes.\n"
            end

            eunif = Msip::Etiqueta.where(
              nombre: Rails.configuration.x.jos19_etiquetaunificadas).take
              if !eunif
                menserror += "No se encontró etiqueta "\
                  "#{Rails.configuration.x.jos19_etiquetaunificadas}.\n"
              end

              if menserror != ""
                return [menserror, nil]
              end

              debugger
              ep = Msip::EtiquetaPersona.new(
                persona_id: p1.id,
                etiqueta_id: eunif.id,
                usuario_id: current_usuario.id,
                fecha: Date.today(),
                observaciones: ""
              )
              [ :anionac, :mesnac, :dianac,
                :numerodocumento, :tdocumento_id,
                :departamento_id, :municipio_id,
                :clase_id, :nacionalde, :pais_id
              ].each do |c|
                if !p1[c] && p2[c]
                  p1[c] = p2[c]
                  ep.observaciones << "#{c}->#{p2[c]}\n"
                end
              end
              p1.save
              ep.save

              Msip::PersonaTrelacion.where(persona1: p2.id).each do |pt|
                pt.persona1 = p1.id
                pt.save
                ep.observaciones << "Cambiada relacion con #{cadpersona} "\
                  "#{pt.persona2}\n"
              end
              Msip::PersonaTrelacion.where(persona2: p2.id).each do |pt|
                pt.persona2 = p1.id
                pt.save
                ep.observaciones << "Cambiada relacion con #{cadpersona} "\
                  "#{pt.persona1}\n"
              end

              #msip_datosbio no debe estar lleno
              Msip::OrgsocialPersona.where(persona_id: p2.id).each do |op|
                op.persona_id = p1.id
                op.save
                ep.observaciones << "Cambiada organización social #{op.orgsocial_id}\n"
              end

              #mr519_gen_encuestapersona no debería estar llena
              Msip::EtiquetaPersona.where(persona_id: p2.id).each do |ep2|
                ep2.persona_id = p1.id
                ep2.save
                ep.observaciones << "Cambiada etiqueta #{ep.etiqueta.nombre}\n"
              end

              Cor1440Gen::Caracterizacionpersona.where(persona_id: p2.id).each do |cp|
                cp.persona_id = p1.id
                cp.save
                ep.observaciones << "Cambiada caracterizacíon #{cp.id}\n"
              end
              # cor1440_gen_beneficiariopf no tiene id
              lpf = Cor1440Gen::Beneficiariopf.where(persona_id: p2.id).
                pluck(:proyectofinanciero_id)
              lpf.each do |pfid|
                if Cor1440Gen::Beneficiariopf.where(persona_id: p1.id, 
                    proyectofinanciero_id: pfid).count == 0
                  Cor1440Gen::Beneficiariopf.connection.execute <<-SQL
                 INSERT INTO cor1440_gen_beneficiariopf 
                   (persona_id, proyectofinanciero_id) 
                   VALUES (#{p1.id}, #{pfid});
                  SQL
                  ep.observaciones << "Cambiado beneficiario en convenio financiado #{pfid}\n"
                end
                Cor1440Gen::Beneficiariopf.connection.execute <<-SQL
               DELETE FROM cor1440_gen_beneficiariopf WHERE 
                 persona_id=#{p2.id} AND
                 proyectofinanciero_id=#{pfid};
                SQL
              end

              unificar_dos_personas_en_casos(
                p1, p2, current_usuario, cadpersona, ep, menserror
              )

              ep.observaciones = ep.observaciones[0..4998]
              ep.save
              p2.destroy
              ep.observaciones << "Se unificó y eliminó el registro de beneficiario #{p2.id}\n"\
                "* Nombres: #{p2.nombres.to_s}\n"\
                "* Apellidos: #{p2.apellidos.to_s}\n"\
                "* Tipo doc.: #{p2.tdocumento_id ? p2.tdocumento.sigla : ''}\n"\
                "* Número de doc.: #{p2.numerodocumento.to_s}\n"\
                "* Año nac.: #{p2.anionac.to_s}\n"\
                "* Mes nac.: #{p2.mesnac.to_s}\n"\
                "* Dia nac.: #{p2.dianac.to_s}\n"\
                "* Sexo nac.: #{p2.sexo.to_s}\n"\
                "* Pais nac.: #{p2.pais_id ? p2.pais.nombre : ''}\n"\
                "* Departamento nac.: #{p2.departamento_id ? p2.departamento.nombre : ''}\n"\
                "* Muncipio nac.: #{p2.municipio_id ? p2.municipio.nombre : ''}\n"\
                "* Centro poblado nac.: #{p2.clase_id ? p2.clase.nombre : ''}\n"\
                "* Nacional de: #{p2.nacionalde ? p2.nacional.nombre : ''}\n"\
                "* Fecha creación: #{p2.created_at.to_s}\n"\
                "* Fecha actualización: #{p2.updated_at.to_s}.\n"

              ep.observaciones = ep.observaciones[0..4998]
              ep.save

              return ["", p1.id]
          end



          # @param c Sivel2Gen::Caso
          # @param menserror Colchon para mensajes de error
          # @return true y menserror no es modificado o false y se agrega problema a menserror
          def eliminar_caso(c, menserror)
            if !c || !c.id
              menserror << "Caso no válido.\n"
              return false
            end
            begin
              #Sivel2Gen::Caso.connection.execute('BEGIN')
              Sivel2Gen::Caso.connection.execute(
                "DELETE FROM sivel2_sjr_categoria_desplazamiento
           WHERE desplazamiento_id IN (SELECT id FROM sivel2_sjr_desplazamiento
              WHERE id_caso=#{c.id});"
              )
              ['sivel2_sjr_ayudasjr_respuesta', 
               'sivel2_sjr_ayudaestado_respuesta',
               'sivel2_sjr_derecho_respuesta', 
               'sivel2_sjr_aspsicosocial_respuesta', 
               'sivel2_sjr_motivosjr_respuesta', 
               'sivel2_sjr_progestado_respuesta'
              ].each do |trr|
                ord = "DELETE FROM #{trr}
           WHERE id_respuesta IN (SELECT id FROM sivel2_sjr_respuesta 
             WHERE id_caso=#{c.id});"
                #puts "OJO ord='#{ord}'"
                Sivel2Gen::Caso.connection.execute(ord)
              end
              Sivel2Gen::Caso.connection.execute(
                "DELETE FROM sivel2_sjr_accionjuridica_respuesta 
           WHERE respuesta_id IN (SELECT id FROM sivel2_sjr_respuesta 
             WHERE id_caso=#{c.id});"
              )

              Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_sjr_actosjr
        WHERE id_acto IN (SELECT id FROM sivel2_gen_acto
          WHERE id_caso=#{c.id});")

              Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_sjr_desplazamiento
        WHERE id_caso=#{c.id};")
              Sivel2Gen::Caso.connection.execute("UPDATE sivel2_gen_caso
        SET ubicacion_id=NULL
          WHERE id=#{c.id};")
              Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET id_llegada=NULL WHERE id_caso=#{c.id};")
              Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET id_salida=NULL WHERE id_caso=#{c.id};")
              Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET id_llegadam=NULL WHERE id_caso=#{c.id};")
              Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET id_salidam=NULL WHERE id_caso=#{c.id};")
              Sivel2Gen::Caso.connection.execute("DELETE FROM sip_ubicacion
        WHERE id_caso=#{c.id};")
              Sivel2Gen::Caso.connection.execute(
                "DELETE FROM sivel2_sjr_actividad_casosjr
        WHERE casosjr_id=#{c.id}")
              Sivel2Gen::Caso.connection.execute(
                "DELETE FROM sivel2_sjr_respuesta 
        WHERE id_caso=#{c.id}")
              cs = c.casosjr
              if cs
                cs.destroy
              end
              c.destroy
              return true
            rescue Exception => e
              menserror << "Problema eliminando caso #{e}.\n"
              return false
            end

            #    Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_gen_acto
            #      WHERE id_caso=#{c.id};")
            #    Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_gen_caso
            #      WHERE id=#{c.id};")
            #    Sivel2Gen::Caso.connection.execute('COMMIT;')
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

            r = unificar_dos_personas(
              id1.dup, id2.dup, current_usuario.dup)
            m = r[0]
            p = r[1]
            if (m != "")
              flash[:error] = m
              redirect_to Rails.configuration.relative_url_root
              return
            end
            redirect_to msip.persona_path(p)
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
              ],
              persona_trelacion1_attributes:  [
                :id,
                :trelacion_id,
                :_destroy,
                :personados_attributes => [
                  :id,
                  :nombres, 
                  :apellidos,
                  :sexo,
                  :tdocumento_id,
                  :numerodocumento,
                ]
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
