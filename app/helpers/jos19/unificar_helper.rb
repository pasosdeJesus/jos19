# frozen_string_literal: true

module Jos19
  module UnificarHelper
    include Rails.application.routes.url_helpers

    # @param c Sivel2Gen::Caso
    # @param menserror Colchon para mensajes de error
    # @return true y menserror no es modificado o false y se agrega problema a menserror
    def eliminar_caso(c, menserror)
      if !c || !c.id
        menserror << "Caso no válido.\n"
        return false
      end
      begin
        # Sivel2Gen::Caso.connection.execute('BEGIN')
        Sivel2Gen::Caso.connection.execute(
          "DELETE FROM sivel2_sjr_categoria_desplazamiento
           WHERE desplazamiento_id IN (SELECT id FROM sivel2_sjr_desplazamiento
              WHERE caso_id=#{c.id});",
        )
        [
          "sivel2_sjr_ayudasjr_respuesta",
          "sivel2_sjr_ayudaestado_respuesta",
          "sivel2_sjr_derecho_respuesta",
          "sivel2_sjr_aspsicosocial_respuesta",
          "sivel2_sjr_motivosjr_respuesta",
          "sivel2_sjr_progestado_respuesta",
        ].each do |trr|
          ord = "DELETE FROM #{trr}
           WHERE respuesta_id IN (SELECT id FROM sivel2_sjr_respuesta
             WHERE caso_id=#{c.id});"
          # puts "OJO ord='#{ord}'"
          Sivel2Gen::Caso.connection.execute(ord)
        end
        Sivel2Gen::Caso.connection.execute(
          "DELETE FROM sivel2_sjr_accionjuridica_respuesta
           WHERE respuesta_id IN (SELECT id FROM sivel2_sjr_respuesta
             WHERE caso_id=#{c.id});",
        )

        Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_sjr_actosjr
        WHERE acto_id IN (SELECT id FROM sivel2_gen_acto
          WHERE caso_id=#{c.id});")

        Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_sjr_desplazamiento
        WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_gen_caso
        SET ubicacion_id=NULL
          WHERE id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET llegada_id=NULL WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET salida_id=NULL WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET llegada_idm=NULL WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("UPDATE sivel2_sjr_casosjr
        SET salida_idm=NULL WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute("DELETE FROM msip_ubicacion
        WHERE caso_id=#{c.id};")
        Sivel2Gen::Caso.connection.execute(
          "DELETE FROM sivel2_sjr_actividad_casosjr
        WHERE casosjr_id=#{c.id}",
        )
        Sivel2Gen::Caso.connection.execute(
          "DELETE FROM sivel2_sjr_respuesta
        WHERE caso_id=#{c.id}",
        )
        cs = c.casosjr
        if cs
          cs.destroy
        end
        c.destroy
        true
      rescue Exception => e
        menserror << "Problema eliminando caso #{e}.\n"
        false
      end

      #    Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_gen_acto
      #      WHERE caso_id=#{c.id};")
      #    Sivel2Gen::Caso.connection.execute("DELETE FROM sivel2_gen_caso
      #      WHERE id=#{c.id};")
      #    Sivel2Gen::Caso.connection.execute('COMMIT;')
    end
    module_function :eliminar_caso

    def consulta_casos_en_blanco
      Sivel2Gen::Caso.joins(:casosjr).where(
        "contacto_id IN (SELECT id FROM msip_persona   " \
          "WHERE COALESCE(nombres, '')=''   " \
          "AND COALESCE(apellidos, '')='') " \
          "AND COALESCE(memo, '')='' ",
      )
    end
    module_function :consulta_casos_en_blanco

    def eliminar_casos_en_blanco
      mens = ""
      pore = UnificarHelper.consulta_casos_en_blanco
      lpore = []
      pore.each do |ce|
        puts "Eliminando caso en blanco #{ce.id}"
        if eliminar_caso(ce, mens)
          lpore += [ce.id]
        else
          puts "Problema eliminando"
        end
      end
      if lpore.count == 0
        "No se eliminaron casos en blanco" +
          (mens != "" ? " (" + mens + ")" : "") + ".\n"
      else
        "Se eliminaron #{lpore.count} casos en blanco " \
          "(#{lpore.join(", ")})" +
          (mens != "" ? " (" + mens + ")" : "") + ".\n"
      end
    end
    module_function :eliminar_casos_en_blanco

    # Crear un casosjr para el caso c  o lo elimina si no tiene víctimas
    # disponibles para esto.
    # @param caso Sivel2Gen::CAso
    # @parama asesor Usuario que quedará como asesor
    # @param lcom Lista de caso completados
    # @param lelim Lista de casos eliminados
    # @param mens Colchon para mensajes de error
    def arreglar_un_caso_medio_borrado(caso, asesor, lcom, lelim, mens)
      if caso.casosjr
        puts "Este caso no necesita ser arreglado"
        return
      end
      if caso.victima_ids == []
        puts "Caso sin víctimas, es mejor eliminarlo"
        if UnificarHelper.eliminar_caso(caso, mens)
          lelim << caso.id
        end
      else
        vpos = caso.victima_ids.select do |vid|
          idp = Sivel2Gen::Victima.find(vid).persona_id
          Sivel2Gen::Victima.where("caso_id<>?", caso.id)
            .where("persona_id<>?", idp).count == 0
        end
        if vpos.count == 0
          puts "Todas las víctimas están en otros casos es mejor eliminarlo"
          if UnificarHelper.eliminar_caso(caso, mens)
            lelim << [caso.id]
          end
        else
          puts "Completando"
          cs = Sivel2Sjr::Casosjr.create(
            caso_id: caso.id,
            contacto_id: vpos[0],
            asesor: us.id,
            oficina: 1, # SIN INFORMACION
          )
          cs.save
          lcom + [caso.id]
        end
      end
    end
    module_function :arreglar_un_caso_medio_borrado

    def consulta_casos_por_arreglar
      Sivel2Gen::Caso.where("id NOT IN (SELECT caso_id FROM sivel2_sjr_casosjr)")
    end
    module_function :consulta_casos_por_arreglar

    def arreglar_casos_medio_borrados
      us = Usuario.habilitados.find_by(rol: Ability::ROLADMIN)
      unless us
        return "No hay un administrador para asignarle casos.\n"
      end

      mens = ""
      lcom = []
      lelim = []
      pora = consulta_casos_por_arreglar
      numpora = pora.count
      pora.each do |c|
        puts "Arreglando caso medio borrado #{c.id}"
        arreglar_un_caso_medio_borrado(c, us, lcom, lelim, mens)
      end
      if numpora == 0
        mens = "No hay casos parcialmente eliminados.\n"
      else
        mens = "De los #{numpora} casos parcialmente eliminados, se completaron #{lcom.count} (i.e #{lcom.join(", ")}) y se eliminaron #{lelim.count} que no tenían beneficiarios o cuyos beneficiarios estaban en otros casos (i.e #{lelim.join(", ")}).\n"
      end
      mens
    end
    module_function :arreglar_casos_medio_borrados

    def consulta_personas_en_blanco_por_eliminar
      Msip::Persona.where(
        "(tdocumento_id is null) AND
      (numerodocumento is null OR numerodocumento='') AND
      id NOT IN (SELECT persona_id FROM cor1440_gen_asistencia) AND
      id NOT IN (SELECT persona_id FROM cor1440_gen_caracterizacionpersona) AND
      id NOT IN (SELECT persona_id FROM msip_orgsocial_persona) AND
      id NOT IN (SELECT persona_id FROM sivel2_gen_victima) AND
      (trim(nombres) IN ('','N','NN')) AND
      (trim(apellidos) in ('','N','NN')) AND
      id NOT IN (SELECT  persona1 FROM msip_persona_trelacion) AND
      id NOT IN (SELECT persona2 FROM msip_persona_trelacion) AND
      id NOT IN (SELECT persona_id FROM detallefinanciero_persona) AND
      id NOT IN (SELECT persona_id FROM cor1440_gen_beneficiariopf)",
      )
    end
    module_function :consulta_personas_en_blanco_por_eliminar

    def eliminar_personas_en_blanco
      pore = consulta_personas_en_blanco_por_eliminar
      lpore = []
      pore.each do |p|
        lpore += ["#{p.id} #{p.nombres} #{p.apellidos}"]
        puts "Eliminando beneficiario en blanco #{p.id}"
        p.destroy
      end
      if lpore.count == 0
        mens = "No hay beneficiarios en blanco.\n"
      else
        mens = "Se eliminaron #{lpore.count} beneficiarios en blanco no asociadas a casos ni a actividades (#{lpore.join(", ")}).\n"
      end
      mens
    end
    module_function :eliminar_personas_en_blanco

    # después de ejecutar este refrescar vista materializada
    # sivel2_gen_conscaso
    def preparar_automaticamente
      mens = arreglar_casos_medio_borrados
      puts mens
      mens2 = eliminar_casos_en_blanco
      puts mens2
      mens += mens2
      mens2 = eliminar_personas_en_blanco
      mens += mens2
      mens
    end
    module_function :preparar_automaticamente

    def reporte_md_contenido_objeto(en, lista_params, objeto, ind)
      # puts "OJO " + ' '*ind + en.to_s + ' '
      res = "".dup
      lista_params.each do |atr|
        # puts "OJO   " + ' '*ind + 'atr: \'' + atr.to_s + '\''
        if atr.class == Symbol
          unless objeto[atr].nil?
            alf = objeto.class.asociacion_llave_foranea(atr)
            if alf
              nclase = alf.class_name.constantize
              orel = nclase.find(objeto[atr])
              res << (" " * ind) + "* " + objeto.class.human_attribute_name(atr) +
                ": " + orel.presenta_nombre.to_s + "\n"
            else
              res << (" " * ind) + "* " + objeto.class.human_attribute_name(atr) +
                ": " + objeto[atr].to_s + "\n"
            end
          end
        elsif atr.class == Hash
          atr.each do |l, v|
            # puts "OJO     " + ' '*ind + 'l: ' + l.to_s
            if v.class != Array
              puts "Se esperaba Array pero en #{l} se encontró #{v.class}\n"
              exit(1)
            elsif l.to_s.end_with?("_attributes")
              nom_nobjeto = l.to_s[0..-12]
              nobjeto = objeto.send(nom_nobjeto)
              # Es colección?
              if nobjeto.class.to_s.end_with?(
                "ActiveRecord_Associations_CollectionProxy",
              )
                i = 0
                nclase2 = nobjeto.class.to_s[0..-44]
                # puts "OJO     " + ' '*ind + 'nclase2= ' + nclase2
                clase2 = nclase2.constantize

                nomh = clase2.human_attribute_name(nom_nobjeto)
                nobjeto.each do |nobjetoind|
                  res << " " * ind + "* #{nomh} #{i + 1}\n"
                  res << reporte_md_contenido_objeto(l, v, nobjetoind, ind + 2)
                  i += 1
                end
              elsif nobjeto.class == NilClass
                res << " " * ind + "* #{nom_nobjeto} es nil"
              else
                nomh = nobjeto.class.human_attribute_name(nom_nobjeto)
                res << " " * ind + "* #{nomh}\n"
                res << reporte_md_contenido_objeto(l, v, nobjeto, ind + 2)
              end
            elsif l.to_s.end_with?("_ids")
              nom_nobjeto = l.to_s[0..-4]
              if objeto.respond_to?(l.to_s)
                res << " " * ind + "* #{nom_nobjeto}: " +
                  "#{objeto.send(l.to_s)}" + "\n"
              end
            end
          end
        end
      end
      res
    end
    module_function :reporte_md_contenido_objeto

    def consulta_duplicados_autom
      # La siguiente vista haría breve la siguiente consulta pero
      # su refresco toma como 15 min.
      #    Msip::Persona.connection.execute <<-SQL
      #       DROP MATERIALIZED VIEW IF EXISTS duplicados_rep;
      #       CREATE MATERIALIZED VIEW duplicados_rep AS (
      #         SELECT sub.sigla,
      #         sub.numerodocumento,
      #         sub.rep,
      #         p1.id AS id1,
      #         p2.id AS id2,
      #         p1.nombres AS nombres1,
      #         p1.apellidos AS apellidos1,
      #         p2.nombres AS nombres2,
      #         p2.apellidos AS apellidos2,
      #         soundexespm(p1.nombres) AS sn1,
      #         soundexespm(p1.apellidos) AS sa1,
      #         soundexespm(p2.nombres) AS sn2,
      #         soundexespm(p2.apellidos) AS sa2
      #         FROM (SELECT t.sigla,
      #           p.tdocumento_id,
      #           p.numerodocumento,
      #           count(p.id) AS rep
      #           FROM msip_persona p
      #             LEFT JOIN msip_tdocumento t ON t.id = p.tdocumento_id
      #           GROUP BY t.sigla, p.tdocumento_id, p.numerodocumento) AS sub
      #         JOIN msip_persona AS p1 ON
      #           p1.tdocumento_id=sub.tdocumento_id
      #           AND p1.numerodocumento=sub.numerodocumento
      #         JOIN msip_persona AS p2 ON
      #           p1.id<p2.id AND
      #           p2.tdocumento_id=sub.tdocumento_id
      #           AND p2.numerodocumento=sub.numerodocumento
      #       );
      #       CREATE INDEX i_duplicado_rep_id1 ON duplicados_rep (id1);
      #       CREATE INDEX i_duplicado_rep_id2 ON duplicados_rep (id2);
      #       CREATE INDEX i_duplicado_rep_numerodocumento ON duplicados_rep (numerodocumento);
      #       CREATE INDEX i_duplicado_rep_sigla ON duplicados_rep (sigla);
      #       CREATE INDEX i_duplicado_rep_n1 ON duplicados_rep (nombres1);
      #       CREATE INDEX i_duplicado_rep_a1 ON duplicados_rep (apellidos1);
      #       CREATE INDEX i_duplicado_rep_n2 ON duplicados_rep (nombres2);
      #       CREATE INDEX i_duplicado_rep_a2 ON duplicados_rep (apellidos2);
      #       CREATE INDEX i_duplicado_rep_tn1 ON duplicados_rep (TRIM(UPPER(unaccent(nombres1))));
      #       CREATE INDEX i_duplicado_rep_ta1 ON duplicados_rep (TRIM(UPPER(unaccent(apellidos1))));
      #       CREATE INDEX i_duplicado_rep_n2 ON duplicados_rep (TRIM(UPPER(unaccent(nombres2))));
      #       CREATE INDEX i_duplicado_rep_a2 ON duplicados_rep (TRIM(UPPER(unaccent(apellidos2))));
      #       CREATE INDEX i_duplicado_rep_sn1 ON duplicados_rep (sn1);
      #       CREATE INDEX i_duplicado_rep_sa1 ON duplicados_rep (sa1);
      #       CREATE INDEX i_duplicado_rep_sn2 ON duplicados_rep (sn2);
      #       CREATE INDEX i_duplicado_rep_sa2 ON duplicados_rep (sa2);
      #    SQL
      depura = ""
      if ENV.fetch("DEPURA_MIN", -1).to_i > 0
        depura << " AND p1.id>#{ENV.fetch("DEPURA_MIN", -1).to_i}"
        depura << " AND p2.id>#{ENV.fetch("DEPURA_MIN", -1).to_i}"
      end
      if ENV.fetch("DEPURA_MAX", -1).to_i > 0
        depura << " AND p1.id<#{ENV.fetch("DEPURA_MAX", -1).to_i}"
        depura << " AND p2.id<#{ENV.fetch("DEPURA_MAX", -1).to_i}"
      end

      Msip::Persona.connection.execute(<<-SQL)

      SELECT p1.tdocumento_id, p1.numerodocumento,#{" "}
        p1.id AS id1, p1.nombres AS nombres1, soundexespm(p1.nombres) AS sn1,
        p1.apellidos AS apellidos1, soundexespm(p1.apellidos) AS sa1,
        p2.id AS id2, p2.nombres AS nombres2, soundexespm(p2.nombres) AS sn2,
        p2.apellidos AS apellidos2, soundexespm(p2.apellidos) AS sa2
      FROM msip_persona AS p1
      JOIN msip_persona AS p2#{" "}
      ON p1.id<p2.id
        #{depura}
        AND p1.tdocumento_id=p2.tdocumento_id
        AND p1.numerodocumento=p2.numerodocumento
      WHERE
        (soundexespm(p1.nombres) = soundexespm(p2.nombres)
          AND soundexespm(p1.apellidos) = soundexespm(p2.apellidos)
        )  --con indices explain da 662.181
      --  OR#{" "}
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
      --  OR#{" "}
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
    module_function :consulta_duplicados_autom

    # después de ejecutar este refrescar vista materializada
    # sivel2_gen_conscaso
    def deduplicar_automaticamente(current_usuario)
      puts "OJO deduplicar_automaticamente"
      puts Benchmark.measure { "a" * 1_000_000_000 }
      pares = UnificarHelper.consulta_duplicados_autom
      puts "OJO consulta efectuada pares.count=#{pares.count}"
      puts Benchmark.measure { "a" * 1_000_000_000 }
      res = {
        titulo: "Beneficiarios en los que se intenta deduplicación automatica",
        encabezado: [
          "T. Doc",
          "Num. doc",
          "Id1",
          "Nombres",
          "Apellidos",
          "Id2",
          "Nombres",
          "Apellidos",
          "Resultado",
        ],
        cuerpo: [],
      }
      pares.each do |f|
        mens, idunif = unificar_dos_personas(f["id1"], f["id2"], current_usuario)
        if mens == ""
          mens = "Unificados en <a target=_blank href='/personas/#{idunif}'>#{idunif}</a>".html_safe
        end
        res[:cuerpo] << [
          ["sigla", f["sigla"]],
          ["numerodocumento", f["numerodocumento"]],
          ["Id. 1", f["id1"]],
          ["Nombres 1", f["nombres1"]],
          ["Apellidos 1", f["apellidos1"]],
          ["Id. 2", f["id2"]],
          ["Nombres 2", f["nombres2"]],
          ["Apellidos 2", f["apellidos2"]],
          ["Restultado", mens],
        ]
      end
      res
    end
    module_function :deduplicar_automaticamente
  end
end
